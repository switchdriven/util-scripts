#!/Users/junya/Scripts/.venv/bin/python3
"""PDFのデジタル署名を検証し、証明書チェーンの詳細を表示する。

pyHankoのPython APIを直接呼び出し、CLI標準出力の文字列パースには依存しない。
署名・失効の検証自体はpyHankoにそのまま任せ、show-cert.py由来の追加分は
証明書チェーン詳細(Subject/Issuer/Serial/有効期間/署名アルゴリズム)の
日本語表示のみとする。
"""

import sys

from asn1crypto import x509
from pyhanko.pdf_utils.reader import PdfFileReader
from pyhanko.sign.validation import validate_pdf_signature
from pyhanko.sign.validation.status import format_pretty_print_details
from pyhanko_certvalidator import ValidationContext
from pyhanko_certvalidator.context import CertValidationPolicySpec, ValidationDataHandlers
from pyhanko_certvalidator.fetchers.requests_fetchers import RequestsFetcherBackend
from pyhanko_certvalidator.ltv.poe import POEManager
from pyhanko_certvalidator.ltv.types import ValidationTimingInfo
from pyhanko_certvalidator.policy_decl import CertRevTrustPolicy, RevocationCheckingPolicy
from pyhanko_certvalidator.registry import CertificateRegistry, SimpleTrustManager
from pyhanko_certvalidator.revinfo.manager import RevinfoManager


def build_validation_context() -> ValidationContext:
    """CLIの `pyhanko sign validate --retroactive-revinfo` 相当の設定を、
    公開APIのみを使って組み立てる(OSの信頼ストアを使用、CRL/OCSPのオンライン
    取得を許可、失効情報が無い場合はhard-fail、失効情報の thisUpdate は
    無視して遡及的に有効とみなす)。
    """
    fetchers = RequestsFetcherBackend().get_fetchers()
    cert_registry = CertificateRegistry(cert_fetcher=fetchers.cert_fetcher)
    poe_manager = POEManager()
    revinfo_manager = RevinfoManager(
        certificate_registry=cert_registry,
        poe_manager=poe_manager,
        crls=[],
        ocsps=[],
        fetchers=fetchers,
    )
    handlers = ValidationDataHandlers(
        revinfo_manager=revinfo_manager,
        poe_manager=poe_manager,
        cert_registry=cert_registry,
    )

    policy = CertValidationPolicySpec(
        trust_manager=SimpleTrustManager.build(),
        revinfo_policy=CertRevTrustPolicy(
            revocation_checking_policy=RevocationCheckingPolicy.from_legacy(
                'hard-fail'
            ),
            retroactive_revinfo=True,
        ),
    )
    vc_kwargs = policy.build_validation_context_kwargs(
        ValidationTimingInfo.now(), handlers=handlers
    )
    return ValidationContext(**vc_kwargs)


def format_cert_detail(cert: x509.Certificate, role: str) -> str:
    return "\n".join(
        [
            f"--- {role} ---",
            f"Subject      : {cert.subject.human_friendly}",
            f"Issuer       : {cert.issuer.human_friendly}",
            f"Serial Number: {cert.serial_number:X}",
            f"Not Before   : {cert.not_valid_before}",
            f"Not After    : {cert.not_valid_after}",
            f"Signature Alg: {cert.hash_algo}_{cert.signature_algo}",
        ]
    )


def show_certificate_chain(embedded_sig) -> None:
    print(format_cert_detail(embedded_sig.signer_cert, "署名者証明書"))
    print()
    for cert in embedded_sig.other_embedded_certs:
        print(format_cert_detail(cert, "中間/ルート証明書"))
        print()


def main(pdf_path: str) -> int:
    with open(pdf_path, "rb") as f:
        reader = PdfFileReader(f, strict=False)
        signatures = list(reader.embedded_regular_signatures)

        if not signatures:
            print("PDF内に署名が見つかりませんでした。")
            return 1

        vc = build_validation_context()

        all_valid = True
        for i, embedded_sig in enumerate(signatures, start=1):
            print(f"===== 署名 {i}: {embedded_sig.field_name} =====")
            print()

            print("[証明書チェーン]")
            show_certificate_chain(embedded_sig)

            status = validate_pdf_signature(
                embedded_sig, signer_validation_context=vc
            )
            print("[検証結果]")
            print(format_pretty_print_details(status, []))

            all_valid &= status.bottom_line

        return 0 if all_valid else 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"使い方: {sys.argv[0]} <PDFファイル>", file=sys.stderr)
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
