# CN evidence checklist

Paths below are relative to this repository's `evidence/` directory. Save the original terminal output or a screenshot showing the command and result. Label copied rehearsal evidence with its actual Mac and date. The filenames below are destinations for Phase 2 and final-demo outputs.

## Phase 1 complete

Use the existing Phase 1 evidence under `evidence/Phase-1/` during the final demo. The remaining evidence collection is listed below.

## Phase 2 files to save

The [Phase 2 report](../phase2/REPORT.md) links the captured results. The [Phase 1 DNS screenshot](Phase-1/DNS/dns-wireshark-query-response.png), [TCP handshake screenshot](Phase-1/TCP/tcp-three-way-handshake.png), and [TLS handshake screenshot](Phase-1/TLS/tls-handshake.png) are available for protocol walkthrough practice. The live demo checklist calls for a saved capture that the evaluator can open.

| Extension | Where and who | Save under `Phase-2/` | What must be visible |
| --- | --- | --- | --- |
| A · Backup DNS | Terminal, all designated demo clients | `A-Backup-DNS/client-dns-mac2.png`, `client-dns-mac3.png` and others if used | Primary `10.7.1.188` and backup `10.7.29.127`, in that order. |
| A · Backup DNS | Terminal, Mac 2 and Mac 1 | `A-Backup-DNS/both-resolvers.png`, `failover.png`, `primary-stop-restore.png` | Both project records via both resolvers, an external record via backup, then default `dig` during the outage with `SERVER: 10.7.29.127#53`. Include proof that Mac 1 was stopped and restored. |
| B · TTL | Terminal, Mac 3 or another designated client | `B-TTL/automatic-expiry.png`, `manual-flush.png` | TTL 30 from an explicit resolver query, timestamped old answer, changed server-side record, then new OS-resolved IP after expiry. On a separate trial show cached old IP immediately before flush and new IP immediately after. |
| C · Isolation | Terminal, Mac 2, Mac 1, Mac 3 and Mac 4 | `C-Isolation/allowed-mac2.png`, `blocked-mac1.png`, `edge-still-serves.png`, `pf-mac3.png`, `pf-mac4.png`, `pf-restore-mac3.png`, `pf-restore-mac4.png` | Direct 200s from Mac 2, direct timeouts from Mac 1, HTTPS success via the edge, backend anchor rules and before/after PF state. |
| D · Backend failover | Terminal, Mac 2 and Mac 3 | `D-Backend-Failover/baseline.png`, `backend-a-down.png`, `backend-a-recovered.png`, `backend-a-stop-start.png` | Six requests per state. Both backend IDs under normal conditions, B-only HTTP 200 during the outage, then both IDs again after recovery. |
| E · Edge migration | Terminal, Mac 2 and Mac 3, two OS cache states | `E-Edge-Migration/preflight.png`, `dns-cutover.png`, `cached-old-edge.png`, `fresh-standby-overlap.png`, `rollback.png`, `rollback-after-overlap-dns.png`, `standby-stopped.png` | Trusted preflight, DNS changed on both resolvers, timestamped normal HTTPS to old and new edge in the same TTL window, then trusted HTTPS to Mac 2, standby listener gone and temporary PF exception removed. |
| F · Faculty fault | Terminal, diagnosing client during evaluation | `F-Troubleshooting/faculty-fault.png` | Fault symptoms, outputs from each layer reached, affected layer, fix or isolation, and successful retest where possible. Save any practice run separately. |
| Integrated demo | Terminal, Mac 2 or another configured client | `HTTPS/trusted-primary.png`, `HTTPS/cache-headers-and-304.png` | Domain URL and verified TLS with HTTP 200, then `Cache-Control`, `ETag` and conditional 304. |
| Integrated demo | Wireshark, Mac 2 or another client | `Packets/protocol-flow.pcapng`, `Packets/dns.png`, `Packets/tcp.png`, `Packets/tls.png` | One saved capture with DNS, TCP and TLS. Screenshots mark the key frames and ports. Optional `Packets/backup-dns.pcapng` shows the successful backup exchange during the outage. |

The converted PNGs show commands and recorded output in Terminal format using the four display prompts supplied by the team. For excerpts without a complete command log, the images identify the recovered commands or the matching capture procedure. PNG metadata retains the original transcript. The packet screenshots were captured in Wireshark.

## Terminal commands

Run from the repo root. Commands below use the test IPs from November 22. Update them if the Wi-Fi IPs change. For fresh runs, save the working log in `/tmp` or capture the Terminal directly. Save the screenshot or rendered transcript under the matching PNG name in the table. Create the destination folder if it is absent.

Use the [Phase 2 runbook](../phase2/README.md#tls-and-standby-edge) to get the verified public primary and standby certificates. The commands below assume the public certs are in Downloads.

### A. DNS availability

On each client, run `bash phase2/scripts/client-dns.sh show`. If needed, set both resolvers with `client-dns.sh set` and save the resulting order. On Mac 2:

```bash
bash phase2/scripts/check.sh dns 2>&1 | tee /tmp/cn-both-resolvers.txt
```

Aman stops primary dnsmasq in its service tab or through its Homebrew service, whichever is active. Mayank runs `bash phase2/scripts/check.sh resolver` on Mac 2 and captures the output for `failover.png`. This command uses default `dig` selection. No explicit resolver should be present. Aman restarts the primary and saves the stop/start transcript. Preserve the prior successful transcript if it includes these details.

### B. TTL expiration and manual flush

Keep the app edge in baseline mode. Set `ttl-demo.team1.test` to Mac 2 on both resolvers. On the client run `dig @10.7.1.188 ttl-demo.team1.test A +noall +answer` to show the TTL and `bash phase2/scripts/check.sh cache` to prime the OS lookup. Change the TTL-demo record to Mac 3 on both servers, keeping the app in baseline mode. Use the third argument to `dns.sh` when restarting the scripted instances. With the existing Mac 1 hosts-file workflow, update `/opt/homebrew/etc/cn-ttl-demo.hosts` and reload dnsmasq. If clients only query the original primary during the test, a server-side update on that resolver suffices for the rehearsal transcript.

After direct DNS shows the new answer, poll `bash phase2/scripts/check.sh cache` on the same client every few seconds without flushing. Save the timestamped outputs through expiry. For the second trial, reset the record and clear the client's cache, prime it again, then change the record. Save one OS lookup before `bash phase2/scripts/client-dns.sh flush` and another immediately after. Direct `dig @server` proves resolver state. `dscacheutil` shows what applications using the macOS resolver can see.

### C and D. Firewall and backend failover

With both backends running and PF isolation active, Mac 2 and Mac 1 each run `bash phase2/scripts/check.sh direct` and save their results separately. On Mac 3/4 save the corresponding `isolation.sh a status` or `isolation.sh b status` output. Use the baseline HTTPS loop for both the isolation and load-balancing evidence when it was captured under those conditions.

```bash
bash phase2/scripts/check.sh repeat "$HOME/Downloads/team1-primary.crt" 6
```

Mayank runs this on Mac 2 before A stops, during the outage, and after A restarts, saving each run to its own file. Ankit stops only Backend A in its Terminal tab and restarts it with `bash phase1/scripts/helpers/mac3-start-backend.sh`. Allow at least the configured upstream failure window after the restart if A has not rejoined yet. Keep the outage log intact.

### E. Cutover and rollback

1. On Mac 4 allow Mac 3 temporarily to reach Backend B. On Mac 3 start standby NGINX. On Mac 2 run `bash phase2/scripts/check.sh standby "$HOME/Downloads/team1-standby.crt"` and capture the trusted preflight. This is the only cutover test intentionally using `--resolve`.
2. On both test clients combine the verified public primary and standby certs with `cat "$HOME/Downloads/team1-primary.crt" "$HOME/Downloads/team1-standby.crt" > "$HOME/Downloads/team1-demo-trust.crt"`. **Ankit on Mac 3** primes the baseline OS cache for the real app name with `bash phase2/scripts/check.sh cache app.team1.test` immediately before cutover. Keep Mac 2's NGINX running. Prepare both DNS operators to switch quickly within the 30-second window.
3. **Aman on Mac 1 and Satyam on Mac 4** switch the app record to the standby. From a separate tab run `check.sh dns` to document both servers answering with Mac 3's IP for the app. **Mayank on Mac 2** flushes the local cache and runs `bash phase2/scripts/check.sh https "$HOME/Downloads/team1-demo-trust.crt"`. **Ankit on Mac 3** runs that same HTTPS command without flushing. Save both timestamped results while both edges respond. Expected old edge `Connected IP: 10.7.28.47`. Expected fresh standby `Connected IP: 10.7.2.152` and `X-Edge: standby-mac3`. Repeat just this test if the old cache expires before the fresh standby result.
4. Restore the app DNS target on both servers to Mac 2, flush the verifying client, then run `check.sh dns` and `check.sh https "$HOME/Downloads/team1-primary.crt"` for the rollback transcript. Stop standby NGINX on Mac 3 and record `lsof -nP -iTCP:8443 -sTCP:LISTEN` for `standby-stopped.png`; empty output is expected. Restore Mac 4's primary-only PF policy and save a failed direct request from Mac 3 to Mac 4's port 3002. That temporary exception rollback is separate from restoring the original PF state.

### Restore the original PF state

After the isolation/migration demo, **Ankit on Mac 3** and **Satyam on Mac 4** save their pre/post PF state. If the anchors were installed by the repo script, run `bash phase2/scripts/isolation.sh a restore` or `bash phase2/scripts/isolation.sh b restore` on the corresponding Mac.

For the already-installed rehearsal rules, use the **original enable token recorded on that Mac**. The handoff says both PF instances were initially disabled. On Mac 3, set the anchor to `com.apple/cn-backend-a`. On Mac 4, set it to `com.apple/cn-backend-b`. Run the following in each backend's Terminal after defining `cn_anchor` and `cn_original_token` from those values. Save the transcript with the token redacted.

```bash
sudo pfctl -s info
sudo pfctl -a "$cn_anchor" -sr
sudo pfctl -a "$cn_anchor" -f /dev/null && sudo pfctl -X "$cn_original_token"
sudo pfctl -s info
sudo pfctl -a "$cn_anchor" -sr
```

The first pair shows the rehearsal rules. The last pair confirms the dedicated anchor is empty and shows the resulting global PF status. If another macOS service owns a PF enable reference, PF may still be enabled. Use only the project's own token.

### F and integrated HTTPS

On the designated client during faculty evaluation, run `bash phase2/scripts/check.sh troubleshoot "$HOME/Downloads/team1-primary.crt"`. Follow the first failing layer, explain the symptom aloud, and repeat after the fix. For the normal integrated demo on Mac 2:

```bash
curl --noproxy '*' --cacert "$HOME/Downloads/team1-primary.crt" -v -i 'https://app.team1.test:8443/api/status' 2>&1 | tee /tmp/cn-trusted-primary.txt
bash phase2/scripts/check.sh headers "$HOME/Downloads/team1-primary.crt" 2>&1 | tee /tmp/cn-cache-headers-and-304.txt
```

The first GET prints the response headers and discards the body. Look for HTTP 200 with `Cache-Control` and `ETag`, followed by HTTP 304 from the conditional GET.

## Wireshark

The [Phase 2 capture](Phase-2/Packets/protocol-flow.pcapng) contains 30 project packets from two Mac 2 captures. The [DNS screenshot](Phase-2/Packets/dns.png) shows the Wi-Fi query to `10.7.1.188` and the answer for `app.team1.test`. The [TCP screenshot](Phase-2/Packets/tcp.png) shows SYN, SYN-ACK and ACK on a loopback connection to the primary edge on port `8443`. The [TLS screenshot](Phase-2/Packets/tls.png) shows Client Hello with `app.team1.test` as SNI and the TLS 1.3 Server Hello on that connection. The browser stopped at the certificate trust warning. The [verified HTTPS transcript](Phase-2/HTTPS/trusted-primary.png) documents the separate successful HTTP request.

On a fresh checkout, run `mkdir -p evidence/Phase-2/Packets` before saving the capture. Use a client whose traffic crosses Wi-Fi to Mac 2, such as Aman on Mac 1 if his machine is configured as a demo client, or Ankit on Mac 3. A request from Mac 2 to Mac 2's own IP may traverse loopback instead of Wi-Fi. On the chosen client, start a capture on its Wi-Fi interface with this **capture filter**:

```text
(port 53 and (host 10.7.1.188 or host 10.7.29.127)) or (tcp port 8443 and host 10.7.28.47)
```

In a second Terminal window on that client, flush its OS DNS cache, then issue a trusted HTTPS request by hostname. For a capture with readable TLS certificate and ChangeCipherSpec handshake records, use TLS 1.2 for this one capture:

```bash
bash phase2/scripts/client-dns.sh flush
curl --noproxy '*' --tlsv1.2 --tls-max 1.2 --cacert "$HOME/Downloads/team1-primary.crt" -v -i 'https://app.team1.test:8443/api/status'
```

Stop the capture. Apply the display filter `dns.qry.name == "app.team1.test" || (tcp.port == 8443 && ip.addr == 10.7.28.47)`. Use **File → Export Specified Packets**, select **Displayed**, and save as `evidence/Phase-2/Packets/protocol-flow.pcapng`. If ordinary HTTPS produced no visible DNS packets, make sure the Wi-Fi resolver is set and the cache is empty, then repeat. If macOS DNS queries the backup, the capture filter includes it. As a separate supplementary query, `dig @10.7.1.188 app.team1.test A` can make the DNS exchange visible. Label it as a separate lookup if used.

| Display filter | Screenshot |
| --- | --- |
| `dns.qry.name == "app.team1.test"` | `dns.png`. Expand the DNS answer and show the resolver IP and returned app address. |
| `tcp.port == 8443` | `tcp.png`. Find the SYN, then apply `tcp.stream == N` using the matching stream index. Show SYN, SYN-ACK and ACK with the client ephemeral port and server port 8443. |
| `tls && tcp.port == 8443` | `tls.png`. Show ClientHello, ServerHello, Certificate, ChangeCipherSpec and encrypted Application Data. If Wireshark does not automatically recognize port 8443, use Decode As → TLS for the stream. |

For optional backup DNS packet evidence, capture the A outage lookup from Mac 2 with the narrow capture filter `port 53 and host 10.7.29.127`. Apply `dns.qry.name == "app.team1.test"` and export only displayed packets as `evidence/Phase-2/Packets/backup-dns.pcapng`. Review captures before adding them to Git, keeping only project traffic. Keep client trust bundles, private keys and PF tokens out of evidence.
