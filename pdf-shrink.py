#!/Users/junya/Scripts/.venv/bin/python3
"""PDF内の埋め込み画像を再圧縮・ダウンサンプリングしてファイルサイズを縮小する。

テキストやベクター部分はラスタライズせず維持し、画像だけを対象にする。
"""

import argparse
import io
import sys
from pathlib import Path

import fitz  # PyMuPDF
from PIL import Image

DEFAULT_MAX_DPI = 150
DEFAULT_JPEG_QUALITY = 70


def shrink_pdf(src: Path, dst: Path, max_dpi: int, quality: int) -> None:
    doc = fitz.open(src)

    for page in doc:
        for img in page.get_images(full=True):
            xref = img[0]
            try:
                base = doc.extract_image(xref)
            except RuntimeError:
                continue

            image = Image.open(io.BytesIO(base["image"]))
            if image.mode != "RGB":
                image = image.convert("RGB")

            rects = page.get_image_rects(xref)
            if not rects:
                continue
            rect = rects[0]
            width_in = rect.width / 72
            height_in = rect.height / 72
            if width_in <= 0 or height_in <= 0:
                continue

            effective_dpi = image.width / width_in
            if effective_dpi > max_dpi:
                scale = max_dpi / effective_dpi
                new_size = (
                    max(1, round(image.width * scale)),
                    max(1, round(image.height * scale)),
                )
                image = image.resize(new_size, Image.LANCZOS)

            buf = io.BytesIO()
            image.save(buf, format="JPEG", quality=quality, optimize=True)
            page.replace_image(xref, stream=buf.getvalue())

    doc.save(dst, garbage=4, deflate=True)
    doc.close()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="PDF内の埋め込み画像を再圧縮・ダウンサンプリングしてファイルサイズを縮小する。"
    )
    parser.add_argument("input", type=Path, help="入力PDFファイル")
    parser.add_argument(
        "-o", "--output", type=Path,
        help="出力PDFファイル(省略時は <input>_shrunk.pdf)",
    )
    parser.add_argument(
        "--max-dpi", type=int, default=DEFAULT_MAX_DPI,
        help=f"画像の最大実効DPI(デフォルト: {DEFAULT_MAX_DPI})",
    )
    parser.add_argument(
        "--quality", type=int, default=DEFAULT_JPEG_QUALITY,
        help=f"JPEG圧縮品質 1-100(デフォルト: {DEFAULT_JPEG_QUALITY})",
    )
    args = parser.parse_args()

    if not args.input.is_file():
        print(f"エラー: 入力ファイルが見つかりません: {args.input}", file=sys.stderr)
        return 1

    output = args.output or args.input.with_name(f"{args.input.stem}_shrunk.pdf")

    shrink_pdf(args.input, output, args.max_dpi, args.quality)

    before = args.input.stat().st_size
    after = output.stat().st_size
    ratio = after / before * 100 if before else 0
    print(
        f"{args.input.name}: {before / 1024 / 1024:.1f}MB -> "
        f"{output.name}: {after / 1024 / 1024:.1f}MB ({ratio:.0f}%)"
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())
