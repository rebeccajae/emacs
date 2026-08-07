# rebeccajae's emacs config
A simple and straightforward one and a half file emacs config.

`init.el` is all of it, then there's `local.el` you can copy from the template.
It contains a basic skeleton of the local configuration, and is gitignored.

The goal was to be sorta similar to vscode/atom/text-editor-of-the-week and
maintaining a lot of discoverability and gradual usability. If you can quit
vim and can read, you'll probably be able to figure it out.

`SPC` is the leader key, and it brings up a nav menu if you tap it and wait.
Alternatively, you can read the `init.el` file to figure out what exists ahead
of time.

Have fun!


## why?
A lot of "old school" editors tend to be a pile of decisions made over decades
and if you had kept up and were using it, you'd have your dotfiles that you
have adapted over years. However, many current-generation editors have a similar
UI, and are fairly prescriptive of how the editor looks. It means it's easier to
get started, but the prescriptivism becomes a challenge when you want to add
small utility extensions and needing to learn how to make a whole extension.

This config should be largely batteries-included, but not completely handed to
you. You'll have to learn to configure parts of it, but you won't really need to
maintain a deep understanding of how to configure every facet of it. It should
be good enough for most day-to-day work, while still being lighter and more
understandable than pre-built distributions.

