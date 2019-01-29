# itch.io Internationalization

This repository stores the internationalization project for the
[itch.io](https://itch.io) website. All source English strings and their
translations are located here. This repository also contains any scripts used
to build translations modules used by the itch.io website to insert localized
strings.

If you'd like to contribute to translations on itch.io then we recommend using
our [Weblate](https://weblate.itch.ovh/projects/itchio/). You can create an
account there and suggest translations. Accepted changes are merged back into
this branch automatically.


## Translations markup guide

### Interpolation

itch.io uses a custom translation markup parser that powers variable
interpolations and formatting of text.

Simple interpolations use the `{{ }}` syntax: 

    Hello {{username}}, welcome back!

When translating strings like these, preserve the `{{ }}` and what is inside.
The name of the variable should give you an idea of what words will be
inserted, so you can place the variable in the correct location for the
translated string.

### Markup

Some translation strings contain an HTML like markup to control formatting of
parts of the string:

    You update your password on <a>your settings page</a>.

When the translation string is rendered, the placeholder tag will be replaced
with the full markup necessary for the page it appears on. In the example
above, the `<a>` placeholder will be replaced with a relevant link.

When translating like these, preserve the placeholder tag and what object it
wraps, but feel free to move it around to ensure grammatically correct text.

### HTML

All translations strings are HTML escaped, so you can't use regular HTML
markup. For example, instead of using `&mdash;` you should use the — character
directly.

## Components

On Weblate, the translation software we use, we've split translation strings
across separate components. A component is a grouping of strings by a feature
on itch.io. This will allow translators to focus a particular part of the site
they'd like to see in their language. The `core` component represents a
critical set of strings that should be translated to enable basic usage of the
site.


