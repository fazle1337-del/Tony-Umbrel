# Gitea MCP (tony-gitea-mcp)

An Umbrel app that runs the official [gitea-mcp](https://gitea.com/gitea/gitea-mcp)
server in **streamable-HTTP** mode and points it at your existing Gitea
instance (`http://192.168.1.118:8085`). It lets AI coding assistants such as
Claude Code interact with your Gitea (repos, issues, PRs, branches, releases)
through the Model Context Protocol.

This is a headless API endpoint — there is no web UI to open.

## Setup

1. **Create a Gitea Personal Access Token**
   In Gitea: avatar → **Settings → Applications → Generate New Token**.
   Give it the scopes you want the assistant to use (typically `repository`,
   `issue`, `read:user`, and `organization` if you work in orgs).

2. **Paste the token into `docker-compose.yml`**
   Replace `REPLACE_WITH_GITEA_TOKEN` with the token value.
   (Token handling is inline by choice — keep this repo private.)

3. **Check `GITEA_HOST`** still matches your Gitea (default
   `http://192.168.1.118:8085`).

4. Commit/push the app store repo, refresh your community app store in Umbrel,
   then install **Gitea MCP**.

## Connect Claude Code

On any machine on your LAN:

```bash
claude mcp add --transport http gitea http://192.168.1.118:8100/mcp
```

Then verify:

```bash
claude mcp list
```

`/mcp` is the streamable-HTTP endpoint; port `8100` is this app's Umbrel port,
proxied to the server's internal `:8080`.

## Notes / troubleshooting

- **Port `8100`** is set in `umbrel-app.yml`. Change it there (and in the
  `claude mcp add` URL) if it clashes with another app.
- **No auth on the endpoint.** Umbrel's proxy auth is disabled
  (`PROXY_AUTH_ADD: "false"`) because MCP clients can't log in through it.
  Anything on your LAN can reach `:8100/mcp`, so keep the token least-privileged
  and never port-forward this to the internet.
- **If the client can't connect**, confirm the server is binding `0.0.0.0`
  inside the container (not just localhost). Check logs on the Umbrel host:
  `sudo docker logs tony-gitea-mcp_mcp_1`. If it bound localhost only, add the
  appropriate bind-address flag to `command:` per the gitea-mcp docs.
- **SSE alternative:** swap the command to `["-t", "sse", "--port", "8080"]`
  and connect with `--transport sse ... http://192.168.1.118:8100/sse`.
