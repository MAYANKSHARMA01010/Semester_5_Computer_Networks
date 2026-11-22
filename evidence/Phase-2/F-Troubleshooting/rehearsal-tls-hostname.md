# Rehearsal troubleshooting — primary TLS hostname mismatch

Mac 2 (Mayank), November 23, 2026. This incident occurred during the team's verification. The faculty trial takes place during evaluation.

| Layer | Observation |
| --- | --- |
| DNS | `app.team1.test` resolved to `10.7.28.47`. |
| TCP | The client connected to `10.7.28.47:8443`. |
| TLS | The edge presented a certificate with `CN=team1.test` and no matching Subject Alternative Name. curl returned error 60. |
| HTTP | The initial request stopped at certificate verification. After repair, `GET /api/status` returned HTTP 200 from Backend A. |

The team reissued the primary certificate using the existing key and added `app.team1.test` and `api.team1.test` as DNS Subject Alternative Names. The NGINX config passed validation. A reload attempt reported an empty PID, and the process and listener checks showed that NGINX had stopped. The team started NGINX with the corrected certificate.

The same URL then matched the certificate's SAN and returned HTTP 200 through the primary edge. The curl command verified the certificate against the project's public certificate.

- [Initial hostname failure](../HTTPS/primary-hostname-mismatch.png)
- [Verified HTTPS retest](../HTTPS/trusted-primary.png)
