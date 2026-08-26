# Authenticated negative fixtures

`cases.json` names every independently rejected binding. Cryptographic corruption
cases represent a nonzero result from the official GitHub CLI verifier; the test
double used when `gh` is unavailable can only reject and is never accepted as proof
of signature, certificate-chain, or Rekor validity. Semantic cases exercise the
wrapper's independent post-verification checks.

T-031 positive verification requires a real `gh` executable, a GitHub-issued artifact
attestation JSON/JSONL bundle, and real `gh attestation trusted-root` JSONL located
outside the repository. The wrapper accepts versioned Sigstore trusted-root records
and leaves their structural and trust validation to `gh`. No repository file is
accepted as a trusted root.
