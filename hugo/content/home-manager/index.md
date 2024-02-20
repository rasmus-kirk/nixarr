---
title: Options Documentation
author: Rasmus Kirk
date: 2023-12-07
---

## kirk.fonts.enable
Whether to enable Enable my fonts, namely fira-code with nerdfonts. Note that this is required for kirk modules that use the nerdfont icons to function properly..

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.foot.alpha
Alpha value of the foot terminal.

*_Type_*:
floating point number


*_Default_*
```
0.85
```




## kirk.foot.colorscheme
A colorscheme attribute set.

*_Type_*:
attribute set


*_Default_*
```
{"bg":"282828","black":"1d2021","blue":"458588","bright":{"black":"928374","blue":"83a598","green":"b8bb26","orange":"fe8019","purple":"d3869b","red":"fb4934","teal":"8ec07c","white":"fbf1c7","yellow":"fabd2f"},"fg":"ebdbb2","green":"98971a","orange":"d65d0e","purple":"b16286","red":"cc241d","teal":"689d6a","white":"d5c4a1","yellow":"d79921"}
```




## kirk.foot.enable
Whether to enable foot terminal emulator.

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.foot.enableKeyBindings
Whether or not to enable my keybindings.

*_Type_*:
boolean


*_Default_*
```
true
```




## kirk.foot.fontSize
Font size of the terminal.

*_Type_*:
signed integer


*_Default_*
```
15
```




## kirk.fzf.colorscheme
A colorscheme attribute set.

*_Type_*:
attribute set


*_Default_*
```
{"bg":"282828","black":"1d2021","blue":"458588","bright":{"black":"928374","blue":"83a598","green":"b8bb26","orange":"fe8019","purple":"d3869b","red":"fb4934","teal":"8ec07c","white":"fbf1c7","yellow":"fabd2f"},"fg":"ebdbb2","green":"98971a","orange":"d65d0e","purple":"b16286","red":"cc241d","teal":"689d6a","white":"d5c4a1","yellow":"d79921"}
```




## kirk.fzf.enable
Whether to enable foot terminal emulator.

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.fzf.enableZshIntegration
Whether to enable zsh integration.

*_Type_*:
boolean


*_Default_*
```
true
```




## kirk.git.enable
Whether to enable git.

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.git.userEmail
What email address to use for git.

*_Type_*:
string






## kirk.git.userName
Username to use for git.

*_Type_*:
string






## kirk.gruvbox.colorscheme
A definition for the gruvbox theme.

*_Type_*:
attribute set


*_Default_*
```
{"bg":"282828","black":"1d2021","blue":"458588","bright":{"black":"928374","blue":"83a598","green":"b8bb26","orange":"fe8019","purple":"d3869b","red":"fb4934","teal":"8ec07c","white":"fbf1c7","yellow":"fabd2f"},"fg":"ebdbb2","green":"98971a","orange":"d65d0e","purple":"b16286","red":"cc241d","teal":"689d6a","white":"d5c4a1","yellow":"d79921"}
```




## kirk.helix.enable
Whether to enable helix text editor.

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.helix.extraPackages
Extra packages to install, for example LSP's.

*_Type_*:
list of package


*_Default_*
```
[]
```




## kirk.helix.installMostLsps
Whether or not to install most of the LSP's that helix supports.

*_Type_*:
boolean


*_Default_*
```
true
```




## kirk.homeManagerScripts.configDir
Path to the home-manager configuration.

*_Type_*:
null or path


*_Default_*
```
null
```




## kirk.homeManagerScripts.enable
Whether to enable home manager scripts.

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.homeManagerScripts.machine
Path to the home-manager configuration.

*_Type_*:
null or string






## kirk.jiten.dailyWord
Enable daily japanese word prompt.

*_Type_*:
boolean


*_Default_*
```
true
```




## kirk.jiten.enable
Whether to enable jiten japanese dictionary.

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.joshuto.enable
Whether to enable joshuto file manager.

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.joshuto.enableZshIntegration
Adds the auto-cd `j` command to zsh.


*_Type_*:
boolean


*_Default_*
```
true
```




## kirk.kakoune.enable
Whether to enable kakoune text editor.

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.ssh.enable
Whether to enable ssh with extra config.

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.ssh.identityPath
The directory containing the path to the identity file.

*_Type_*:
null or path


*_Default_*
```
null
```




## kirk.terminalTools.autoUpdateTealdeer
Whether to auto-update tealdeer.

*_Type_*:
boolean


*_Default_*
```
true
```




## kirk.terminalTools.enable
Whether to enable Quality of life terminal tools.

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.terminalTools.enableZshIntegration
Whether to enable zsh integration for bat.

*_Type_*:
boolean


*_Default_*
```
true
```




## kirk.terminalTools.theme
What syntax highlighting colorscheme to use.

*_Type_*:
string


*_Default_*
```
"gruvbox-dark"
```




## kirk.terminalTools.trashCleaner.enable
Enable the trash-cli cleanup script

*_Type_*:
boolean


*_Default_*
```
true
```




## kirk.terminalTools.trashCleaner.persistance
How many days a file stays in trash before getting cleaned up.

*_Type_*:
signed integer or floating point number


*_Default_*
```
30
```




## kirk.userDirs.autoSortDownloads
Whether or not to auto-sort downloads.


*_Type_*:
boolean


*_Default_*
```
true
```




## kirk.userDirs.enable
Whether to enable userDirs.

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.zathura.colorscheme
A colorscheme attribute set.


*_Type_*:
attribute set


*_Default_*
```
{"bg":"282828","black":"1d2021","blue":"458588","bright":{"black":"928374","blue":"83a598","green":"b8bb26","orange":"fe8019","purple":"d3869b","red":"fb4934","teal":"8ec07c","white":"fbf1c7","yellow":"fabd2f"},"fg":"ebdbb2","green":"98971a","orange":"d65d0e","purple":"b16286","red":"cc241d","teal":"689d6a","white":"d5c4a1","yellow":"d79921"}
```




## kirk.zathura.enable
Whether to enable foot terminal emulator.

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.zathura.enableKeyBindings
Whether or not to enable my keybindings.


*_Type_*:
boolean


*_Default_*
```
true
```




## kirk.zsh.enable
Whether to enable zsh configuration..

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


