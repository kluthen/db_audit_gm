# pages.sh (DO NOT TAMPER): the bastion's page functions, sourced by
# gm-entrypoint (the home, the documentation site) and render-status (the
# partners' status pages); v0.6 master spec 7.2 to 7.6, capture W2 item 2.
# Every page: a full HTML document, its title escaped, a link home.

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
body { max-width: 52rem; margin: 0 auto; padding: 0 1rem 2rem; font-family: sans-serif; line-height: 1.5; }
table { border-collapse: collapse; }
th, td { border: 1px solid #ccc; padding: 0.2rem 0.5rem; text-align: left; vertical-align: top; }
pre { overflow-x: auto; background: #f4f4f4; padding: 0.5rem; }
nav.home { border-bottom: 1px solid #ccc; padding: 0.5rem 0; }
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
