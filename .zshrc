# Отключаем grml prompt, чтобы не мешал starship
prompt off

# Базовые настройки
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

# Алиасы (сокращения команд)
alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias update='sudo pacman -Syu'
alias c='clear'

# Горячие клавиши для поиска по истории (стрелки вверх/вниз)
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Подключение плагинов (пути для Arch Linux)
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

export PATH="$HOME/.local/bin:$PATH"
export VIRTUAL_ENV_DISABLE_PROMPT=1

export _ZO_DOCTOR=0
eval "$(zoxide init zsh)"
alias cd='z'

# Инициализация красивого промпта (должен быть последним)
eval "$(starship init zsh)"

# Вывод красивого логотипа при старте
fastfetch
alias claude-danger='claude --dangerously-skip-permissions'
export PATH="$HOME/.cargo/bin:$PATH"
