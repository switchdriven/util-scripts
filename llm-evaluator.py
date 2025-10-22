#!/usr/bin/env python3
"""
OpenAI準拠のAPIでアクセスできるLLMのトークン/秒を評価するスクリプト
"""

import time
import json
import statistics
import argparse
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
import requests

@dataclass
class TestResult:
    """テスト結果を格納するデータクラス"""
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int
    response_time: float
    tokens_per_second: float
    model: str
    prompt_length: int

class LLMSpeedEvaluator:
    """LLMの速度評価を行うクラス"""
    
    def __init__(self, api_key: str, base_url: str = "https://api.openai.com/v1", 
                 api_type: str = "openai"):
        """
        初期化
        
        Args:
            api_key: APIキー
            base_url: APIのベースURL
            api_type: API種別 ("openai", "litellm", "ollama")
        """
        self.api_key = api_key
        # localhostを127.0.0.1に自動変換（IPv4/IPv6問題の回避）
        self.base_url = self._normalize_localhost(base_url.rstrip('/'))
        self.api_type = api_type.lower()
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
    
    def _normalize_localhost(self, url: str) -> str:
        """localhostを127.0.0.1に正規化"""
        if '://localhost:' in url:
            normalized = url.replace('://localhost:', '://127.0.0.1:')
            print(f"📡 Auto-converted {url} → {normalized}")
            return normalized
        elif url.endswith('://localhost'):
            normalized = url.replace('://localhost', '://127.0.0.1')
            print(f"📡 Auto-converted {url} → {normalized}")
            return normalized
        return url
    
    def count_tokens_estimate(self, text: str) -> int:
        """
        テキストのトークン数を大まかに推定
        （実際のトークナイザーがない場合の代替手段）
        """
        # 単語数の約1.3倍をトークン数として推定（英語の場合）
        # 日本語の場合はより複雑だが、文字数/2程度で推定
        words = text.split()
        if any(ord(char) > 127 for char in text):  # 日本語文字が含まれる場合
            return len(text) // 2
        else:
            return int(len(words) * 1.3)
    
    def send_request(self, prompt: str, model: str, max_tokens: int = 500, 
                    temperature: float = 0.7) -> Dict[str, Any]:
        """
        APIリクエストを送信
        
        Args:
            prompt: プロンプト
            model: モデル名
            max_tokens: 最大トークン数
            temperature: 温度パラメータ
            
        Returns:
            APIレスポンス
        """
        # API種別に応じてペイロードとエンドポイントを設定
        if self.api_type == "ollama":
            return self._send_ollama_request(prompt, model, max_tokens, temperature)
        else:
            return self._send_openai_request(prompt, model, max_tokens, temperature)
    
    def _send_ollama_request(self, prompt: str, model: str, max_tokens: int, 
                           temperature: float) -> Dict[str, Any]:
        """Ollama API用のリクエスト送信"""
        payload = {
            "model": model,
            "prompt": prompt,
            "stream": False,
            "options": {
                "num_predict": max_tokens,
                "temperature": temperature
            }
        }
        
        headers = {"Content-Type": "application/json"}
        url = f"{self.base_url}/api/generate"
        
        start_time = time.time()
        response = requests.post(url, headers=headers, json=payload, timeout=120)
        end_time = time.time()
        
        if response.status_code != 200:
            raise Exception(f"Ollama API request failed: {response.status_code} - {response.text}")
        
        result = response.json()
        result['response_time'] = end_time - start_time
        return result
    
    def _send_openai_request(self, prompt: str, model: str, max_tokens: int, 
                           temperature: float) -> Dict[str, Any]:
        """OpenAI/LiteLLM API用のリクエスト送信"""
        payload = {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": max_tokens,
            "temperature": temperature,
            "stream": False
        }
        
        # クエリパラメータとしてAPIキーを追加（LiteLLMの特殊設定対応）
        if self.api_type == "litellm" or ("localhost" in self.base_url and not self.base_url.endswith("/v1")):
            url = f"{self.base_url}/chat/completions?key={self.api_key}"
            headers = {"Content-Type": "application/json"}
        else:
            url = f"{self.base_url}/chat/completions"
            headers = self.headers
        
        start_time = time.time()
        response = requests.post(url, headers=headers, json=payload, timeout=120)
        end_time = time.time()
        
        if response.status_code != 200:
            raise Exception(f"API request failed: {response.status_code} - {response.text}")
        
        result = response.json()
        result['response_time'] = end_time - start_time
        
        if 'choices' not in result or not result['choices']:
            print(f"DEBUG: Unexpected API response structure: {result}")
        
        return result
    
    def evaluate_single_prompt(self, prompt: str, model: str, 
                             max_tokens: int = 500) -> TestResult:
        """
        単一のプロンプトで評価を実行
        
        Args:
            prompt: テストプロンプト
            model: モデル名
            max_tokens: 最大トークン数
            
        Returns:
            テスト結果
        """
        print(f"Testing prompt (length: {len(prompt)} chars)...")
        
        response = self.send_request(prompt, model, max_tokens)
        
        # API種別に応じてレスポンスを解析
        if self.api_type == "ollama":
            return self._parse_ollama_response(response, prompt, model)
        else:
            return self._parse_openai_response(response, prompt, model)
    
    def _parse_ollama_response(self, response: Dict[str, Any], prompt: str, 
                             model: str) -> TestResult:
        """Ollamaレスポンスの解析"""
        # Ollamaのレスポンス構造: {"response": "text", "done": true, ...}
        content = response.get('response', '')
        
        if not content:
            print(f"    ⚠ Warning: No response content from Ollama")
            content = "[No content returned]"
        
        # Ollamaはトークン使用量の詳細情報を提供
        prompt_eval_count = response.get('prompt_eval_count', 0)
        eval_count = response.get('eval_count', 0)
        
        # トークン数が提供されない場合は推定
        prompt_tokens = prompt_eval_count if prompt_eval_count > 0 else self.count_tokens_estimate(prompt)
        completion_tokens = eval_count if eval_count > 0 else self.count_tokens_estimate(content)
        total_tokens = prompt_tokens + completion_tokens
        
        response_time = response['response_time']
        tokens_per_second = completion_tokens / response_time if response_time > 0 and completion_tokens > 0 else 0
        
        # Ollamaの追加情報を表示
        if 'total_duration' in response:
            total_duration_sec = response['total_duration'] / 1e9  # ナノ秒から秒に変換
            print(f"    📊 Ollama stats - Prompt tokens: {prompt_tokens}, Eval tokens: {completion_tokens}")
            print(f"    ⏱  Total duration: {total_duration_sec:.2f}s, Eval duration: {response.get('eval_duration', 0) / 1e9:.2f}s")
        
        return TestResult(
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            total_tokens=total_tokens,
            response_time=response_time,
            tokens_per_second=tokens_per_second,
            model=model,
            prompt_length=len(prompt)
        )
    
    def _parse_openai_response(self, response: Dict[str, Any], prompt: str, 
                             model: str) -> TestResult:
        """OpenAI/LiteLLMレスポンスの解析"""
        # レスポンスからコンテンツを安全に取得
        content = ""
        try:
            if 'choices' in response and response['choices']:
                choice = response['choices'][0]
                if 'message' in choice:
                    message = choice['message']
                    if 'content' in message and message['content']:
                        content = message['content']
                    else:
                        print(f"    ⚠ Warning: No content in message. Message keys: {list(message.keys())}")
                        content = f"[No content returned - finish_reason: {choice.get('finish_reason', 'unknown')}]"
                elif 'text' in choice:
                    content = choice['text']
                else:
                    content = "[Unknown response format]"
            else:
                raise KeyError("No choices in response")
        except Exception as e:
            print(f"    ✗ Error extracting content: {e}")
            print(f"    Debug - Full response: {response}")
            raise
        
        # トークン使用量を取得
        usage = response.get('usage', {})
        prompt_tokens = usage.get('prompt_tokens', self.count_tokens_estimate(prompt))
        
        # Gemini特有の処理：text_tokensがある場合はそれを、なければcompletion_tokensを使用
        if 'completion_tokens_details' in usage and 'text_tokens' in usage['completion_tokens_details']:
            completion_tokens = usage['completion_tokens_details']['text_tokens']
            reasoning_tokens = usage['completion_tokens_details'].get('reasoning_tokens', 0)
            print(f"    📊 Tokens - Text: {completion_tokens}, Reasoning: {reasoning_tokens}")
        else:
            completion_tokens = usage.get('completion_tokens', self.count_tokens_estimate(content))
        
        # テキストトークンが0の場合の特別処理
        if completion_tokens == 0:
            print(f"    ⚠ Warning: No text tokens generated (only reasoning tokens)")
            total_completion = usage.get('completion_tokens', 0)
            if total_completion > 0:
                completion_tokens = total_completion
                print(f"    📊 Using total completion tokens for calculation: {completion_tokens}")
        
        total_tokens = usage.get('total_tokens', prompt_tokens + completion_tokens)
        
        response_time = response['response_time']
        tokens_per_second = completion_tokens / response_time if response_time > 0 and completion_tokens > 0 else 0
        
        return TestResult(
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            total_tokens=total_tokens,
            response_time=response_time,
            tokens_per_second=tokens_per_second,
            model=model,
            prompt_length=len(prompt)
        )
    
    def run_evaluation(self, model: str, test_prompts: Optional[List[str]] = None, 
                      max_tokens: int = 500, iterations: int = 1) -> List[TestResult]:
        """
        評価を実行
        
        Args:
            model: モデル名
            test_prompts: テストプロンプトのリスト
            max_tokens: 最大トークン数
            iterations: 各プロンプトの実行回数
            
        Returns:
            テスト結果のリスト
        """
        if test_prompts is None:
            test_prompts = self.get_default_prompts()
        
        results = []
        total_tests = len(test_prompts) * iterations
        current_test = 0
        
        print(f"Starting evaluation for model: {model}")
        print(f"Total tests to run: {total_tests}")
        print("-" * 50)
        
        for i, prompt in enumerate(test_prompts):
            print(f"\nPrompt {i+1}/{len(test_prompts)}:")
            
            for iteration in range(iterations):
                current_test += 1
                print(f"  Iteration {iteration+1}/{iterations} (Test {current_test}/{total_tests})")
                
                try:
                    result = self.evaluate_single_prompt(prompt, model, max_tokens)
                    results.append(result)
                    print(f"    ✓ {result.completion_tokens} tokens in {result.response_time:.2f}s "
                          f"({result.tokens_per_second:.2f} tokens/sec)")
                    
                    # APIレート制限を考慮して少し待機
                    time.sleep(0.5)
                    
                except Exception as e:
                    print(f"    ✗ Error: {str(e)}")
        
        return results
    
    def get_default_prompts(self) -> List[str]:
        """デフォルトのテストプロンプトを取得（Gemini向けに最適化）"""
        return [
            "Please write a detailed response about artificial intelligence. Explain what AI is, how it works, and its applications in various fields.",
            
            "Tell me a story about a young inventor who creates a time machine. Include dialogue, character development, and describe the adventures they have.",
            
            "Explain quantum computing in detail. Describe the principles, how quantum computers work, their advantages over classical computers, and potential applications.",
            
            "Write a comprehensive guide for making homemade pizza. Include ingredient lists, step-by-step instructions, tips for the perfect crust, and topping suggestions.",
            
            "Describe the process of photosynthesis in plants. Explain both light-dependent and light-independent reactions, the role of chlorophyll, and why this process is important for life on Earth.",
            
            "Write an analysis of renewable energy sources. Compare solar, wind, hydroelectric, and geothermal power in terms of efficiency, cost, environmental impact, and scalability.",
            
            "Create a detailed explanation of how the internet works. Include information about protocols, routers, DNS, web servers, and how data travels across networks."
        ]
    
    def print_statistics(self, results: List[TestResult]):
        """統計情報を出力"""
        if not results:
            print("No results to analyze.")
            return
        
        tokens_per_sec = [r.tokens_per_second for r in results]
        response_times = [r.response_time for r in results]
        completion_tokens = [r.completion_tokens for r in results]
        
        print("\n" + "="*60)
        print("EVALUATION RESULTS")
        print("="*60)
        
        print(f"Model: {results[0].model}")
        print(f"Total tests: {len(results)}")
        print(f"Successful tests: {len([r for r in results if r.tokens_per_second > 0])}")
        
        print("\nTokens per Second:")
        print(f"  Average: {statistics.mean(tokens_per_sec):.2f}")
        print(f"  Median:  {statistics.median(tokens_per_sec):.2f}")
        print(f"  Min:     {min(tokens_per_sec):.2f}")
        print(f"  Max:     {max(tokens_per_sec):.2f}")
        if len(tokens_per_sec) > 1:
            print(f"  Std Dev: {statistics.stdev(tokens_per_sec):.2f}")
        
        print("\nResponse Time (seconds):")
        print(f"  Average: {statistics.mean(response_times):.2f}")
        print(f"  Median:  {statistics.median(response_times):.2f}")
        print(f"  Min:     {min(response_times):.2f}")
        print(f"  Max:     {max(response_times):.2f}")
        
        print("\nCompletion Tokens:")
        print(f"  Average: {statistics.mean(completion_tokens):.0f}")
        print(f"  Median:  {statistics.median(completion_tokens):.0f}")
        print(f"  Min:     {min(completion_tokens)}")
        print(f"  Max:     {max(completion_tokens)}")
        
        print("\nDetailed Results:")
        print("-" * 60)
        for i, result in enumerate(results):
            print(f"Test {i+1:2d}: {result.completion_tokens:3d} tokens, "
                  f"{result.response_time:5.2f}s, {result.tokens_per_second:6.2f} tok/sec")
    
    def save_results(self, results: List[TestResult], filename: str):
        """結果をJSONファイルに保存"""
        data = []
        for result in results:
            data.append({
                'model': result.model,
                'prompt_tokens': result.prompt_tokens,
                'completion_tokens': result.completion_tokens,
                'total_tokens': result.total_tokens,
                'response_time': result.response_time,
                'tokens_per_second': result.tokens_per_second,
                'prompt_length': result.prompt_length,
                'timestamp': time.time()
            })
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        
        print(f"\nResults saved to: {filename}")

def main():
    """メイン関数"""
    parser = argparse.ArgumentParser(description='Evaluate LLM token generation speed')
    parser.add_argument('--api-key', required=True, help='API key')
    parser.add_argument('--model', default='gpt-3.5-turbo', help='Model name (default: gpt-3.5-turbo)')
    parser.add_argument('--base-url', default='https://api.openai.com/v1', 
                       help='API base URL (default: OpenAI)')
    parser.add_argument('--api-type', default='openai', choices=['openai', 'litellm', 'ollama'],
                       help='API type (default: openai)')
    parser.add_argument('--max-tokens', type=int, default=500, 
                       help='Maximum tokens per response (default: 500)')
    parser.add_argument('--iterations', type=int, default=1, 
                       help='Number of iterations per prompt (default: 1)')
    parser.add_argument('--output', help='Output JSON file for results')
    parser.add_argument('--prompts-file', help='JSON file containing custom prompts')
    
    args = parser.parse_args()
    
    # カスタムプロンプトの読み込み
    test_prompts = None
    if args.prompts_file:
        try:
            with open(args.prompts_file, 'r', encoding='utf-8') as f:
                test_prompts = json.load(f)
            print(f"Loaded {len(test_prompts)} custom prompts from {args.prompts_file}")
        except Exception as e:
            print(f"Error loading prompts file: {e}")
            return
    
            # 評価の実行
    evaluator = LLMSpeedEvaluator(args.api_key, args.base_url, args.api_type)
    
    try:
        results = evaluator.run_evaluation(
            model=args.model,
            test_prompts=test_prompts,
            max_tokens=args.max_tokens,
            iterations=args.iterations
        )
        
        evaluator.print_statistics(results)
        
        # 結果の保存
        if args.output:
            evaluator.save_results(results, args.output)
        
    except KeyboardInterrupt:
        print("\nEvaluation interrupted by user.")
    except Exception as e:
        print(f"Error during evaluation: {e}")

if __name__ == "__main__":
    main()