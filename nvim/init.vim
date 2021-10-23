""""""""""""""""""""""""""""""""""""""""""""""""""
"                   GENERAL                      "
""""""""""""""""""""""""""""""""""""""""""""""""""
set nocompatible            " Disable compatibility to old-time vi
set showmatch               " Show matching brackets.
set ignorecase              " Do case insensitive matching
set hlsearch                " highlight search results
set nu rnu                  " add line numbers
set wildmode=longest,list   " get bash-like tab completions
"Enable mouse click for nvim
set mouse=a
"Fix cursor replacement after closing nvim
set guicursor=


""""""""""""""""""""""""""""""""""""""""""""""""""
"                   WHITE SPACE                  "
""""""""""""""""""""""""""""""""""""""""""""""""""
set tabstop=2               " number of columns occupied by a tab character
set softtabstop=2           " see multiple spaces as tabstops so <BS> does the right thing
set expandtab               " converts tabs to white space
set shiftwidth=2            " width for autoindents
set autoindent              " indent a new line the same amount as the line just typed

set list listchars=tab:>\ ,trail:+,eol:$ " See invisible characters

inoremap <S-Tab> <C-d>


""""""""""""""""""""""""""""""""""""""""""""""""""
"                   PLUGINS                      "
""""""""""""""""""""""""""""""""""""""""""""""""""
call plug#begin(stdpath('data') . '/plugged')
" vim-surround
Plug 'tpope/vim-surround'

" gitgutter
Plug 'airblade/vim-gitgutter'

" fugitive
Plug 'tpope/vim-fugitive'

" Readline style insertion
Plug 'tpope/vim-rsi'

" vimwiki
Plug 'vimwiki/vimwiki'

" Color schemes
Plug 'christianchiarulli/nvcode-color-schemes.vim'

" tree sitter
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

" Deoplete
Plug 'Shougo/deoplete.nvim', {'do': ':UpdateRemotePlugins'}

" tree sitter
Plug 'preservim/nerdtree'

" Terraform intellisense
Plug 'hashivim/vim-terraform'

" Syntastic
Plug 'vim-syntastic/syntastic'

" Terraform Autocompletion 
Plug 'juliosueiras/vim-terraform-completion'

" vim-ariline/vim-ariline
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" configure treesitter
call plug#end()

let g:deoplete#omni_patterns = {}
let g:deoplete#omni_patterns.terraform = '[^ *\t"{=$]\w*'
let g:deoplete#enable_at_startup = 1
call deoplete#initialize()

" Syntastic Config
" set statusline+=%#warningmsg#
" set statusline+=%{SyntasticStatuslineFlag()}
" set statusline+=%*
" 
" let g:syntastic_always_populate_loc_list = 1
" let g:syntastic_auto_loc_list = 1
" let g:syntastic_check_on_open = 1
" let g:syntastic_check_on_wq = 0
" let g:syntastic_python_python_exec = 'python3'
" let g:syntastic_python_checkers = ['python']

" (Optional)Remove Info(Preview) window
set completeopt-=preview

" (Optional)Hide Info(Preview) window after completions
autocmd CursorMovedI * if pumvisible() == 0|pclose|endif
autocmd InsertLeave * if pumvisible() == 0|pclose|endif

" (Optional) Enable terraform plan to be include in filter
let g:syntastic_terraform_tffilter_plan = 1

" (Optional) Default: 0, enable(1)/disable(0) plugin's keymapping
let g:terraform_completion_keys = 1

" (Optional) Default: 1, enable(1)/disable(0) terraform module registry completion
let g:terraform_registry_module_completion = 1

""""""""""""""""""""""""""""""""""""""""""""""""""
"               PLUGINS SETTINGS                 "
""""""""""""""""""""""""""""""""""""""""""""""""""

" Enable maintained parsers for nvim-treesitter
lua << EOF
require'nvim-treesitter.configs'.setup {
  ensure_installed = "maintained", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  highlight = {
    enable = true,              -- false will disable the whole extension
  },
}
EOF

" Disable Indent Lines for vimwiki
" autocmd FileType vimwiki : IndentLinesDisable
autocmd FileType wiki : indentLineDisable

" Airline
let g:airline_theme="onedark"
let g:airline#extensions#tabline#formatter = 'unique_tail_improved'
""""""""""""""""""""""""""""""""""""""""""""""""""
"                   COLORS                       "
""""""""""""""""""""""""""""""""""""""""""""""""""

" Enable Syntax Highlighting
syntax on

" checks if your terminal has 24-bit color support
if (has("termguicolors"))
  set termguicolors
  hi LineNr ctermbg=NONE guibg=NONE
endif

" Set colorscheme and amount of colors
let g:nvcode_termcolors=256
colorscheme nvcode

" Set 80 char column border
set cc=80
hi ColorColumn ctermbg=11

""""""""""""""""""""""""""""""""""""""""""""""""""
"                   MOVEMENTS                    "
""""""""""""""""""""""""""""""""""""""""""""""""""
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

