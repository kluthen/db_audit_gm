# pages.sh (DO NOT TAMPER): the bastion's page functions, sourced by
# gm-entrypoint (the home, the documentation site) and render-status (the
# partners' status pages); v0.6 master spec 7.2 to 7.6, capture W2 item 2.
# Every page: a full HTML document, its title escaped, a link home, and one
# small inline stylesheet (no external resource: games run offline), light
# or dark after the browser's prefers-color-scheme.

# html_escape: stdin to stdout, HTML-escaped (& < > ").
html_escape() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

# page_open <title, escaped> [home]: the document's head and the body's
# start; `home` leaves out the link home.
page_open() {
    cat <<PAGE
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$1</title>
<style>
:root { color-scheme: light dark; --bg: #f6f7f9; --fg: #1f2328; --muted: #59636e; --card: #ffffff;
  --line: #d8dde3; --accent: #1f6feb; --code: #eef1f4; --head: #f0f3f6; }
@media (prefers-color-scheme: dark) {
  :root { --bg: #15181d; --fg: #e3e6ea; --muted: #9aa4af; --card: #1d2127; --line: #353c46;
    --accent: #7cacff; --code: #262b33; --head: #232830; } }
* { box-sizing: border-box; }
html { background: var(--bg); color: var(--fg); }
body { max-width: 58rem; margin: 0 auto; padding: 0.5rem 1.25rem 3rem; line-height: 1.6;
  font: 16px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, "Noto Sans", "Helvetica Neue", Arial, sans-serif; }
a { color: var(--accent); text-underline-offset: 0.15em; }
h1, h2, h3, h4 { line-height: 1.25; margin: 1.5em 0 0.6em; }
h1 { font-size: 1.9rem; margin-top: 0.9em; }
h2 { font-size: 1.4rem; padding-bottom: 0.3em; border-bottom: 1px solid var(--line); }
h3 { font-size: 1.15rem; }
header p, .note, .updated { color: var(--muted); }
main > section { background: var(--card); border: 1px solid var(--line); border-radius: 10px;
  padding: 0.1rem 1.25rem 0.9rem; margin: 1.25rem 0; }
main > section > h2 { border-bottom: 0; margin-top: 0.8em; }
section#access { border-left: 4px solid var(--accent); }
ul, ol { padding-left: 1.5rem; }
li { margin: 0.2rem 0; }
code, pre, kbd { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; font-size: 0.9em; }
code { background: var(--code); padding: 0.1em 0.35em; border-radius: 4px; overflow-wrap: anywhere; }
pre { background: var(--code); padding: 0.75rem 1rem; border-radius: 6px; overflow-x: auto; line-height: 1.45; }
pre code { background: none; padding: 0; overflow-wrap: normal; }
table { border-collapse: collapse; margin: 1rem 0; display: block; overflow-x: auto; max-width: 100%; }
th, td { border: 1px solid var(--line); padding: 0.4rem 0.7rem; text-align: left; vertical-align: top; }
th { background: var(--head); font-weight: 600; }
blockquote { margin: 1rem 0; padding: 0.1rem 1rem; border-left: 4px solid var(--line); color: var(--muted); }
hr { border: 0; border-top: 1px solid var(--line); margin: 2rem 0; }
nav.home { padding: 0.75rem 0; border-bottom: 1px solid var(--line); font-weight: 600; }
nav.home a { text-decoration: none; }
</style>
</head>
<body>
PAGE
    [ "${2:-}" = home ] || printf '<nav class="home"><a href="/">Home</a></nav>\n'
    printf '<main>\n'
}

page_close() {
    printf '</main>\n</body>\n</html>\n'
}

# md_title <markdown file> <fallback>: the file's first `# ` heading, else
# <fallback>; not escaped.
md_title() {
    t=$(sed -n 's/^# \{1,\}\(.*[^ #]\)[ #]*$/\1/p' "$1" | head -n 1)
    printf '%s' "${t:-$2}"
}

# md_page <markdown file> <title> [status map]: the file as a page, by
# cmark-gfm with the table extension, raw HTML never passed through (its
# safe default: never --unsafe), headings given ids by html-ids. Fails when
# cmark-gfm does.
md_page() {
    _body=$(cmark-gfm -e table "$1") || return 1
    page_open "$(printf '%s' "$2" | html_escape)"
    printf '%s\n' "$_body" | perl /usr/local/lib/gm/html-ids "${3:-}" || return 1
    page_close
}

# put_page <path>: stdin into <path> through a temporary file moved into
# place, root:www-data 0440 (the front's account reads it).
put_page() {
    cat > "$1.tmp" || return 1
    chown root:www-data "$1.tmp" && chmod 0440 "$1.tmp" && mv -f "$1.tmp" "$1"
}
