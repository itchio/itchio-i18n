# itch.io Internationalization

[![Actions Status](https://github.com/itchio/itchio-i18n/workflows/test/badge.svg)](https://github.com/itchio/itchio-i18n/actions)

This repository stores the internationalization project for the
[itch.io](https://itch.io) website. All source English strings and their
translations are located here. This repository also contains any scripts used
to build translations modules used by the itch.io website to insert localized
strings.

If you'd like to contribute to translations on itch.io then we recommend using
our [Weblate](https://weblate.itch.ovh/projects/itchio/). You can create an
account there and suggest translations. Accepted changes are merged back into
this branch automatically.

## Languages DB

The `languages.json` file lists the identifier and name for all supported
languages on itch.io. Supported languages are available for:

* Site translations
* Project tagging

> Making changes to `language.json`? Please ensure it remains sorted. You can
> use `js -S` to sort the file. Please ensure you use a valid code referenced
> here: https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes

## Translations markup guide

itch.io uses a custom translation markup parser that powers variable
interpolations and formatting of text.

### Interpolation

Variables are inserted with the `{{ }}` syntax:

    Hello {{username}}, welcome back!

When translating strings with a variable, preserve the `{{ }}` and what is
inside. The name of the variable should give you an idea of what words will be
inserted. Use this information to place the variable in the grammatically
correct location for the translated string.

### Markup

Some translation strings contain an HTML-like markup to control formatting of
parts of the string:

    You update your password on <a>your settings page</a>.

When the translated string is displayed, the placeholder tag will be replaced
with the full markup needed for the page it appears on. In the example above,
the `<a>` placeholder will be replaced with a relevant link.

When translating strings like these, preserve the placeholder tag and what object it
wraps, but feel free to move it around to ensure grammatically correct text.

Do not add additional markup, if it isn't already in the source string then it
throw an error. These tags are not HTML, but actually work more like variables.

### HTML

All translation strings are HTML escaped when displayed, HTML markup will not
render. For example, instead of using `&mdash;` you should use the — character
directly.

HTML tags are not supported, only the markup syntax from the example above.

## How markup works

A common problem with internationalization is how to handle strings that
contain markup. Here's an example string that needs to be made available for
translators:

    To log in, <a href="http://website" class="login_link">click here</a> and type your password

For a proper translation, the entire string must be sent as a single line of
text. An English speaker might think they can split it into three separate
strings, `To log in`, `click here`, and `and type your password`, but the
grammar of many languages requires the parts of the sentence to be in different
positions.  Additionally, a translator typically is viewing a single string at
a time. The cut up chunks give no context, which would lead to confusing the
translator and a poor translation.

To avoid this, you could include the entire text with markup verbatim for the
translator to work with. The translator would be expected to work around the
HTML, moving it if necessary. Although it works, there are many downsides with
this approach:

* If the markup is complicated, then it makes it much more difficult to work with. The translator could easily make a mistake and break the functionality of the page.
* The markup is frozen into the translation files. If it needs to be updated later, then every translation must be edited by a programmer.
* Putting raw HTML into the translation string means that it would be rendered in the page without HTML escaping. A XSS vulnerability may be introduced, with additional risk from a crowdsourced translation. Stray characters could break the entire page.

To solve all of these problems, we've come up with a special reduced syntax:

    To log in, <a>click here</a> and type your password

It looks like HTML, but it only supports a tag names with no attributes.
Because it's a subset of HTML, it's much easier to validate. It's also very
short, so it's easy for translators to work with it. Regular text can be
rendered HTML escaped to prevent any invalid markup or vulnerabilities.

The `a` in this example actually references a variable named `a`. In our code
we pass a function that is responsible for rendering the full HTML tag. The
variable name is flexible, it doesn't have a to be a single letter, and it
doesn't need to match the original tag. It could be `<b>`, `<1>`,
`<loginlink>`, etc.

Here's how it looks like on the code end when rendered into the page (in MoonScript):


```moon
-- "index.user_log_in" is the name of the key that holds the example string
@t "index.user_log_in", {
  a: (...) -> a href: @url_for("log_in"), class: "log_in_link", ...
}
```

All the data associated with the `a` tag is kept in our source code, and not
embedded in the translations. The attributes of the tag can be updated with a
simple change, and all existing translations will continue work.


### Optimizing the translations

Because the markup of the translation can contain more complicated syntax, I
decided to invest some time in ahead-of-time compilation to ensure translations
don't slow down the page rendering.

Without any special optimizations, the simplest approach would be to fetch the
string, parse it, and replace all the interpolations during page request time.
Both parsing and rendering would require many allocations, loops, checks, and
other things. To avoid this, we can *compile* the string at build time to
ensure a fast render.

Using `lpeg` we can [parse the translation string into a syntax tree](https://github.com/itchio/itchio-i18n/blob/master/helpers/compiler.moon#L10), then using
the MoonSciprt Lua compiler we can [turn that AST into Lua code](https://github.com/itchio/itchio-i18n/blob/master/helpers/compiler.moon#L40). The
translations module can be rendered with the Lua code directly inside of it
ready to be called.

Here's an example:

    To log in, <a>click here</a> and type your password


This string is parsed into the following structure:

    [
      "To log in, "
      {
        tag: "a"
        contents: [
          "click here"
        ]
      }
      " and type your password"
    ]

It's an array of chunks, where a chunk is either a string, or a object
describing the tag. The tag object contains a `contents` array that recursively
can contain strings or tags.

The next step is to turn it into Lua syntax nodes that MoonScript knows how to
compile, then compile it. The output of the compiler is this:

```lua
function(text_fn, variables)
  text_fn("To log in, ")
  variables.a("click here")
  text_fn(" and type your password")
end
```

`text_fn` is a function that is used to write text to the output buffer. In
Lapis, this is the `text` function available within a widget.

Because the function is compiled into Lua during the build step, at runtime
it's ready to be called to efficient write the translated string to the output
buffer. A [special script](https://github.com/itchio/itchio-i18n/blob/master/build_translations.moon) is used to convert all the `json` files produced by
Weblate into a single `.lua` module that can be loaded by the web app.


