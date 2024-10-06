" =====================================
" ============ Basic Settings =========
" =====================================

" Be improved, required
set nocompatible
" Required
filetype plugin indent on

" Reduces flicker and speeds up macros
set lazyredraw
" Faster redrawing
set ttyfast

" Enable syntax highlighting
syntax on

" Display line numbers and relative line numbers
set number
set relativenumber

" Toggle relative numbers and numbers on/off
nnoremap <F3> :set invnumber<CR>
nnoremap <F4> :set invrnu<CR>

" Configure tabs and indentation
set tabstop=4        " Number of spaces in a tab
set shiftwidth=4     " Number of spaces for indentation
set expandtab        " Use spaces instead of tabs
set autoindent       " Auto-indent new lines

" Set clipboard to use the system clipboard
set clipboard=unnamedplus

" Configure split behavior
set splitbelow       " New horizontal splits appear below
set splitright       " New vertical splits appear to the right

" Enable mouse support in all modes
set mouse=a
" Enable mouse in Normal and Visual modes
"set mouse=nv

" Set encoding to UTF-8 for consistency
set encoding=utf-8

" Configure backspace behavior
set backspace=indent,eol,start

" Leader key configuration (must be set before any mappings that use <leader>)
let mapleader = ","

" Enable 256 colors for Vim when running inside tmux
"if $TERM =~ 'tmux-256colors'
"  set t_Co=256
"endif

let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"

" Optionally enable true color support for Vim if your terminal supports it
if has("termguicolors")
  set termguicolors
endif

" Disable arrow keys in Normal and Visual Modes to encourage use of hjkl
nnoremap <Up> <Nop>
nnoremap <Down> <Nop>
nnoremap <Left> <Nop>
nnoremap <Right> <Nop>
vnoremap <Up> <Nop>
vnoremap <Down> <Nop>
vnoremap <Left> <Nop>
vnoremap <Right> <Nop>

" =====================================
" ==== Whitespace Highlighting ========
" =====================================

" Highlight trailing whitespace
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/

" Update trailing whitespace highlighting on various events
autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
autocmd InsertLeave * match ExtraWhitespace /\s\+$/
autocmd BufWinLeave * call clearmatches()

" =====================================
" ==== Quit and Clipboard Mappings =====
" =====================================

" Prevent accidental use of :Q by remapping it to :quit
command! -bar -bang Q quit<bang>

" Clipboard mappings for easier copy-paste operations
inoremap <leader>v <ESC>"+pa
vnoremap <leader>c "+y
vnoremap <leader>d "+d

" =====================================
" ======== Split Navigation ============
" =====================================

" Navigate between splits using Ctrl + H/J/K/L
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" =====================================
" ============ Folding Settings =========
" =====================================

" Use marker-based folding
set foldmethod=marker

" Toggle folds using the spacebar
nnoremap <space> za

" Optional: Open all folds by default
" set foldlevelstart=99

" =====================================
" ======= Plugin Management ============
" =====================================

" Ensure plugin directories exist
if !isdirectory(expand('~/.vim/pack/plugins/start'))
    call mkdir(expand('~/.vim/pack/plugins/start'), "p")
endif

if !isdirectory(expand('~/.vim/pack/colors/start'))
    call mkdir(expand('~/.vim/pack/colors/start'), "p")
endif

" Activate Optional Plugins
" packadd! python-mode

" =====================================
" ======== NERDTree Configuration =====
" =====================================

" Automatically open NERDTree when no file is specified
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif

" Toggle NERDTree with Ctrl+E
nnoremap <C-E> :NERDTreeToggle<CR>

" Close Vim if NERDTree is the only window open
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" =====================================
" ======== VIMUX Configuration =========
" =====================================

" Prompt for a command to run
nnoremap <Leader>vp :VimuxPromptCommand<CR>

" Run the last command executed by VimuxRunCommand
nnoremap <Leader>vl :VimuxRunLastCommand<CR>

" Inspect the runner pane
nnoremap <Leader>vi :VimuxInspectRunner<CR>

" Zoom the tmux runner pane
nnoremap <Leader>vz :VimuxZoomRunner<CR>

" =====================================
" ======== Airline Configuration =======
" =====================================

" Enable Powerline fonts for Airline
let g:airline_powerline_fonts = 1

" Enable all status line sections in vim-airline
let g:airline#extensions#tabline#enabled = 1  " Enable tabline
let g:airline#extensions#tabline#formatter = 'default'  " Use default tabline
let g:airline_section_a = '%{airline#util#prepend(airline#parts#mode(), 0)}'
let g:airline_section_b = '%{airline#util#prepend(airline#parts#branch(), 0)}'
let g:airline_section_c = '%f'
let g:airline_section_x = '%{airline#util#prepend(airline#parts#filetype(), 0)}'
let g:airline_section_y = '%{airline#util#prepend(airline#parts#readonly(), 0)}'
let g:airline_section_z = '%l:%v'

" Customizing the information displayed in the Airline status line
let g:airline_section_a = airline#section#create(['mode'])
let g:airline_section_b = airline#section#create(['branch', 'hunks'])
let g:airline_section_c = airline#section#create(['%f'])
let g:airline_section_x = airline#section#create(['%{&fileencoding?&fileencoding:&encoding}'])
let g:airline_section_y = airline#section#create(['fileformat', 'filetype'])
let g:airline_section_z = airline#section#create(['%l/%L:%c'])

" Automatically save the current Airline theme when Vim exits
autocmd VimLeave * call SaveAirlineThemeToFile()

" Define available Airline themes
let g:airline_themes = [
\ 'alduin', 'angr', 'apprentice', 'atomic', 'ayu_dark', 'ayu_light', 'ayu_mirage', 'badwolf',
\ 'base16_3024', 'base16_adwaita', 'base16_apathy', 'base16_ashes', 'base16_atelier_cave_light',
\ 'base16_atelier_cave', 'base16_atelier_dune_light', 'base16_atelier_dune', 'base16_atelier_estuary_light',
\ 'base16_atelier_estuary', 'base16_atelier_forest_light', 'base16_atelier_forest', 'base16_atelier_heath_light',
\ 'base16_atelier_heath', 'base16_atelier_lakeside_light', 'base16_atelier_lakeside', 'base16_atelier_plateau_light',
\ 'base16_atelier_plateau', 'base16_atelier_savanna_light', 'base16_atelier_savanna', 'base16_atelier_seaside_light',
\ 'base16_atelier_seaside', 'base16_atelier_sulphurpool_light', 'base16_atelier_sulphurpool', 'base16_atlas',
\ 'base16_bespin', 'base16_black_metal', 'base16_black_metal_bathory', 'base16_black_metal_burzum', 'base16_black_metal_dark_funeral',
\ 'base16_black_metal_gorgoroth', 'base16_black_metal_immortal', 'base16_black_metal_khold', 'base16_black_metal_marduk', 'base16_black_metal_mayhem',
\ 'base16_black_metal_nile', 'base16_black_metal_venom', 'base16_brewer', 'base16_bright', 'base16_brogrammer', 'base16_brushtrees_dark',
\ 'base16_brushtrees', 'base16_chalk', 'base16_circus', 'base16_classic_dark', 'base16_classic_light', 'base16_codeschool', 'base16_colors', 
\ 'base16_cupcake', 'base16_cupertino', 'base16_darktooth', 'base16_decaf', 'base16_default_dark', 'base16_default_light', 'base16_dracula',
\ 'base16_edge_dark', 'base16_edge_light', 'base16_eighties', 'base16_embers', 'base16_espresso', 'base16_flat', 'base16_framer', 'base16_fruit_soda',
\ 'base16_gigavolt', 'base16_github', 'base16_google_dark', 'base16_google_light', 'base16_grayscale_dark', 'base16_grayscale_light',
\ 'base16_gruvbox_dark_hard', 'base16_gruvbox_dark_medium', 'base16_gruvbox_dark_pale', 'base16_gruvbox_dark_soft', 'base16_gruvbox_light_hard',
\ 'base16_gruvbox_light_medium', 'base16_gruvbox_light_soft', 'base16_harmonic16', 'base16_harmonic_dark', 'base16_harmonic_light', 
\ 'base16_heetch_light', 'base16_heetch', 'base16_helios', 'base16_hopscotch', 'base16_horizon_dark', 'base16_horizon_light', 
\ 'base16_horizon_terminal_dark', 'base16_horizon_terminal_light', 'base16_ia_dark', 'base16_ia_light', 'base16_icy', 'base16_irblack', 
\ 'base16_isotope', 'base16_londontube', 'base16_macintosh', 'base16_marrakesh', 'base16_material_darker', 'base16_material_lighter', 
\ 'base16_material_palenight', 'base16_material', 'base16_material_vivid', 'base16_materia', 'base16_mellow_purple', 'base16_mexico_light', 
\ 'base16_mocha', 'base16_monokai', 'base16_nord', 'base16_nova', 'base16_oceanicnext', 'base16_ocean', 'base16_onedark', 'base16_one_light', 
\ 'base16_outrun_dark', 'base16_papercolor_dark', 'base16_papercolor_light', 'base16_paraiso', 'base16_phd', 'base16_pico', 'base16_pop', 
\ 'base16_porple', 'base16_railscasts', 'base16_rebecca', 'base16_sandcastle', 'base16_seti', 'base16_shapeshifter', 'base16_shell', 
\ 'base16_snazzy', 'base16_solarflare', 'base16_solarized_dark', 'base16_solarized_light', 'base16_solarized', 'base16_spacemacs', 
\ 'base16_summerfruit_dark', 'base16_summerfruit_light', 'base16_synth_midnight_dark', 'base16_tomorrow_night_eighties', 'base16_tomorrow_night', 
\ 'base16_tomorrow', 'base16_tube', 'base16_twilight', 'base16_unikitty_dark', 'base16_unikitty_light', 'base16_vim', 'base16_woodland', 
\ 'base16_xcode_dusk', 'base16_zenburn', 'behelit', 'biogoo', 'blood_red', 'bubblegum', 'cobalt2', 'cool', 'cyberpunk', 'dark_minimal', 
\ 'desertink', 'deus', 'distinguished', 'durant', 'fairyfloss', 'fruit_punch', 'google_dark', 'google_light', 'hybridline', 'hybrid', 
\ 'jellybeans', 'jet', 'kalisi', 'kolor', 'laederon', 'lessnoise', 'lighthaus', 'light', 'lucius', 'luna', 'minimalist', 'molokai', 
\ 'monochrome', 'murmur', 'night_owl', 'nord_minimal', 'onedark', 'ouo', 'owo', 'papercolor', 'peaksea', 'powerlineish', 'qwq', 'ravenpower',
\ 'raven', 'seagull', 'selenized_bw', 'selenized', 'seoul256', 'serene', 'sierra', 'silver', 'simple', 'soda', 'solarized_flood', 'solarized', 
\ 'sol', 'supernova', 'term_light', 'term', 'tomorrow', 'transparent', 'ubaryd', 'understated', 'violet', 'wombat', 'xtermlight', 'zenburn'
\ ]

" Initialize the current Airline theme index
let g:current_airline_theme = 0

" Function to switch to the next Airline theme
function! NextAirlineTheme()
    let g:current_airline_theme = (g:current_airline_theme + 1) % len(g:airline_themes)
    let airline_theme = g:airline_themes[g:current_airline_theme]
    try
        execute 'AirlineTheme ' . airline_theme
        echo "Airline theme set to " . airline_theme
    catch /^Vim\%((\a\+)\)\=:E185/
        echohl ErrorMsg | echo "Error: Airline theme " . airline_theme . " not found." | echohl None
    catch
        echohl ErrorMsg | echo "An unexpected error occurred while setting the Airline theme." | echohl None
    endtry
endfunction

" Function to switch to the previous Airline theme
function! PrevAirlineTheme()
    let g:current_airline_theme = (g:current_airline_theme - 1 + len(g:airline_themes)) % len(g:airline_themes)
    let airline_theme = g:airline_themes[g:current_airline_theme]
    try
        execute 'AirlineTheme ' . airline_theme
        echo "Airline theme set to " . airline_theme
    catch /^Vim\%((\a\+)\)\=:E185/
        echohl ErrorMsg | echo "Error: Airline theme " . airline_theme . " not found." | echohl None
    catch
        echohl ErrorMsg | echo "An unexpected error occurred while setting the Airline theme." | echohl None
    endtry
endfunction


" Function to save the current Airline theme as default
function! SaveAirlineThemeToFile()
    let airline_theme = g:airline_themes[g:current_airline_theme]
    call writefile([airline_theme], expand('~/.vim/airline_theme.conf'))
    echo "Airline theme saved as default: " . airline_theme
endfunction

" Load the saved Airline theme if available
if filereadable(expand('~/.vim/airline_theme.conf'))
    let saved_theme = trim(readfile(expand('~/.vim/airline_theme.conf'))[0])
    let index = index(g:airline_themes, saved_theme)
    if index != -1
        let g:current_airline_theme = index
        let g:airline_theme = saved_theme
        try
            echo "Loaded saved Airline theme: " . saved_theme
        catch /^Vim\%((\a\+)\)\=:E185/
            echohl ErrorMsg | echo "Error: Saved Airline theme " . saved_theme . " not found." | echohl None
        catch
            echohl ErrorMsg | echo "An unexpected error occurred while loading the Airline theme." | echohl None
        endtry
    endif
endif

" Custom key mappings for Airline theme cycling and saving
nnoremap <leader>an :call PrevAirlineTheme()<CR>
nnoremap <leader>ap :call NextAirlineTheme()<CR>
nnoremap <leader>as :call SaveAirlineThemeToFile()<CR>

" =====================================
" ======== FZF Configuration ===========
" =====================================

" Add FZF to runtime path
set rtp+=~/.fzf

" Customize FZF colors
let g:fzf_colors = {
\ 'fg':      ['fg', 'Normal'],
\ 'bg':      ['bg', 'Normal'],
\ 'hl':      ['fg', 'Comment'],
\ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
\ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
\ 'hl+':     ['fg', 'Statement'],
\ 'info':    ['fg', 'PreProc'],
\ 'border':  ['fg', 'Ignore'],
\ 'prompt':  ['fg', 'Conditional'],
\ 'pointer': ['fg', 'Exception'],
\ 'marker':  ['fg', 'Keyword'],
\ 'spinner': ['fg', 'Label'],
\ 'header':  ['fg', 'Comment'] }

" FZF Mappings
nnoremap <C-p> :Files<CR>
" Alternative functionalities (uncomment as needed)
" nnoremap <leader>f :Files<CR>
" nnoremap <leader>b :Buffers<CR>
" nnoremap <leader>m :History<CR>
nnoremap <leader>r :Rg<CR>
nnoremap <leader>g :GFiles<CR>

" Command to search text in project using ripgrep (rg)
command! -nargs=* Rg call fzf#vim#grep(
\   'rg --column --line-number --no-heading --color=always --smart-case '.shellescape(<q-args>), 1,
\   fzf#vim#with_preview(), <bang>0)

" =====================================
" ======== Fugitive Mappings ==========
" =====================================

" Git status
nnoremap <leader>gs :vertical Gstatus<CR>

" Git commit
nnoremap <leader>gc :Gcommit<CR>

" Git push
nnoremap <leader>gp :Gpush<CR>

" Git blame
nnoremap <leader>gb :Git blame<CR>

" Git log
nnoremap <leader>gl :Glog<CR>

" Git diff split
nnoremap <leader>gd :Gdiffsplit<CR>

" Git edit
nnoremap <leader>gq :Gedit<CR>

" Git vdiff split
nnoremap <leader>gm :Gvdiffsplit!<CR>

" Git add current file
nnoremap <leader>ga :Git add %<CR>

" Git reset current file
nnoremap <leader>gr :Git reset %<CR>

" Git fetch
nnoremap <leader>gf :Git fetch<CR>

" Git checkout branch
nnoremap <leader>gbr :Git checkout<Space>

" Git checkout and create new branch
nnoremap <leader>gcb :Git checkout -b<Space>

" Git delete branch
nnoremap <leader>gdb :Git branch -d<Space>

" Git browse (opens in browser)
nnoremap <leader>go :GBrowse<CR>
vmap <leader>go :GBrowse<CR>

" Uncomment for additional Git functionalities
" nnoremap <leader>gs :Git stash<CR>
" nnoremap <leader>gS :Git stash pop<CR>
" nnoremap <leader>grb :Git rebase -i<CR>     " Start interactive rebase
" nnoremap <leader>gch :Git cherry-pick<Space> " Cherry-pick a commit
" nnoremap <leader>gsub :Git submodule update --init --recursive<CR>
" nnoremap <leader>gfp :Git push --force-with-lease<CR>
" nnoremap <leader>gt :Git tag<CR>
" nnoremap <leader>gct :Git checkout tags/<Space>
" nnoremap <leader>gd :Gdiffsplit -w<CR>

" =====================================
" ======== ALE Configuration ==========
" =====================================

" Define linters for various filetypes
let g:ale_linters = {
    \   'python': ['flake8', 'pylint', 'mypy'],
    \   'sh': ['shellcheck'],
    \   'make': ['checkmake'],
    \   'vhdl': ['hdl_checker', 'ghdl'],
    \   'c': ['clangd'],
    \   'cpp': ['clangd'],
    \   'perl': ['perl'],
    \   'ruby': ['rubocop'],
    \   'yaml': ['yamllint'],
    \   'markdown': ['markdownlint'],
    \   'latex': ['chktex'],
    \}

" Define fixers for various filetypes
let g:ale_fixers = {
\   'python': ['autopep8'],
\   'sh': ['shfmt'],
\   'make': ['shfmt'],
\}

" Enable fixing and linting on save
let g:ale_fix_on_save = 1
let g:ale_lint_on_save = 1

" Set ALE sign priority lower than CoC's
let g:ale_sign_priority = 5

" ALE-specific settings for Python
let g:ale_python_flake8_options = '--max-line-length=88'  " Follow PEP8 line length
let g:ale_python_pylint_options = '--disable=C0111'      " Disable missing docstring warning
let g:ale_python_mypy_options = '--ignore-missing-imports'  " Ignore missing imports

" Set ALE executables
let g:ale_python_pylint_executable = 'pylint'
let g:ale_python_flake8_executable = 'flake8'

" ALE settings for Bash (shellcheck)
let g:ale_sh_shellcheck_options = '--severity=style'  " Set shellcheck severity

" Enable ALE linting and fixing for VHDL
let g:ale_vhdl_hdl_checker_executable = 'hdl_checker'  " Use hdl_checker as linter
" let g:ale_vhdl_hdl_checker_executable = 'ghdl'    " Use ghdl as linter
let g:ale_vhdl_hdl_checker_options = '--strict'      " Enable strict VHDL linting

" Set custom linter for Make
let g:ale_make_checkmake_executable = 'checkmake'

" Display linting errors and warnings as gutter signs
" let g:ale_virtualtext_cursor = 1
" let g:ale_sign_column_always = 1

" Disable ALE's autocompletion
let g:ale_completion_enabled = 0

" =====================================
" ======== CoC Configuration ==========
" =====================================

" Define CoC extensions
let g:coc_global_extensions = [
    \ 'coc-python', 'coc-sh', 'coc-json', 'coc-clangd',
    \ 'coc-solargraph', 'coc-markdownlint', 'coc-yaml',
    \ 'coc-html', 'coc-css', 'coc-tsserver', 'coc-texlab'
    \ ]

" Use <Tab> and <S-Tab> for navigating the completion menu
inoremap <silent><expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <silent><expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

" Use <CR> to confirm completion
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm() : "\<C-g>u\<CR>"

" Use <C-space> to manually trigger completion
inoremap <silent><expr> <C-space> coc#refresh()

" Navigate diagnostics
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" Show diagnostics in a floating window
nnoremap <silent> <leader>cd :call CocActionAsync('diagnosticHover')<CR>

" Go to definition, references, or implementation
nnoremap <silent> gd <Plug>(coc-definition)
nnoremap <silent> gr :call CocAction('jumpReferences')<CR>
nnoremap <silent> gi :call CocAction('jumpImplementation')<CR>

" Rename symbol
nnoremap <silent> <leader>rn <Plug>(coc-rename)

" Show documentation
nnoremap <silent> K :call CocActionAsync('doHover')<CR>

" Automatically fix errors using CoC's formatter
nnoremap <silent> <leader>cf :call CocAction('format')<CR>

" Code actions for selected region
xnoremap <silent> <leader>ac :<C-u>CocActionAsync('rangeCodeAction')<CR>
nnoremap <silent> <leader>ac :CocActionAsync('codeAction')<CR>

" Show the signature of the function you are typing
inoremap <silent><expr> <C-k> coc#pum#visible() ? "\<C-e>" : "\<C-g>u\<C-k>"

" Check for installed extensions
command! -nargs=0 CocListExtensions :CocList extensions

" Run the extension installer after Vim has fully loaded, silently
autocmd VimEnter * silent! call InstallCoCExtensions()

" CoC snippet support with shared keybindings
"inoremap <silent><expr> <C-b> coc#pum#visible() ? "\<C-n>" :
"    \ (coc#expandable() ? "\<C-r>=coc#rpc#request('snippetNext', [])\<CR>" :
"    \ UltiSnips#CanJumpForwards() ? "\<C-r>=UltiSnips#JumpForwards()<CR>" :
"    \ "\<C-b>")
"inoremap <silent><expr> <C-z> coc#pum#visible() ? "\<C-p>" :
"    \ (coc#expandable() ? "\<C-r>=coc#rpc#request('snippetPrev', [])\<CR>" :
"    \ UltiSnips#CanJumpBackwards() ? "\<C-r>=UltiSnips#JumpBackwards()<CR>" :
"    \ "\<C-z>")

" =====================================
" ======== Copilot Configuration ======
" =====================================

" Disable Copilot's default <Tab> mapping
let g:copilot_no_tab_map = v:true

" Accept Copilot suggestions with <leader><Tab>
imap <silent><expr> <leader><Tab> copilot#Accept("\<Tab>")

" Use Ctrl-] to dismiss Copilot suggestions
inoremap <C-]> <Plug>(copilot-dismiss)

" Enable Copilot for all filetypes (uncomment if needed)
" let g:copilot_filetypes = {'*': v:true}

" =====================================
" ======== Python-Specific Config =======
" =====================================

" === Jedi-vim Configuration ====
" Uncomment if you choose to use Jedi-vim instead of CoC for Python autocompletion
" autocmd FileType python setlocal omnifunc=jedi#completions
" let g:jedi#completions_enabled = 1
" let g:jedi#show_call_signatures = "2"
" let g:jedi#popup_on_dot = 1
" let g:jedi#completions_case_sensitive = 0
" let g:jedi#auto_initialization = 1
" let g:jedi#force_py_version = 3
" let g:jedi#environment_path = "/path/to/your/venv"
" let g:jedi#completions_enabled = 0
" let g:jedi#goto_assignments_command = "gk"
" nnoremap <leader>d :JediGotoDefinition<CR>
" nnoremap <leader>k :JediShowDocs<CR>
" nnoremap <leader>a :JediGotoAssignment<CR>
" nnoremap <leader>u :JediFindUsages<CR>
" let g:jedi#use_splits_not_buffers = "right"

" === Python-Mode Configuration ====
" Uncomment if you choose to use python-mode instead of CoC or Jedi-vim
" let g:pymode = 1
" let g:pymode_lint = 1
" let g:pymode_lint_checker = 'pylint'
" let g:pymode_lint_cwindow = 1  " Open quickfix window on lint errors
" let g:pymode_folding = 1
" let g:pymode_folding_symbols = 1
" let g:pymode_virtualenv = 1
" let g:pymode_run = 1
" let g:pymode_run_key = '<F5>'
" let g:pymode_lint_checker = 'flake8'
" let g:pymode_rope = 1
" let g:pymode_rope_completion_on_dot = 1
" let g:pymode_lint_pep8 = 1
" let g:pymode_lint_checker = 'pyflakes'
" let g:pymode_rope_jedi = 1
" let g:pymode_lint_on_write = 1
" let g:pymode_lint_on_fly = 0
" let g:pymode_format = 1
" let g:pymode_format_on_save = 1
" let g:pymode_tests_doctest = 1
" let g:pymode_python = '/path/to/your/python'
" let g:pymode_indent = 1
" let g:pymode_indent_hanging = 0

" === pydocstring Configuration ====
let g:pydocstring_doq_path = '/usr/local/bin/doq'
let g:pydocstring_doq_style = 'google'
let g:pydocstring_auto_generate = 1

" Use <leader>ds to generate docstrings
nnoremap <leader>ds :Pydocstring<CR>

" =====================================
" ======== UltiSnips Configuration =====
" =====================================

" Define snippet directories
let g:UltiSnipsSnippetDirectories = ['UltiSnips', 'vim-snippets']

" Set snippet triggers
"let g:UltiSnipsListSnippets = "C-Tab>"
let g:UltiSnipsExpandTrigger = "<Tab>"
"let g:UltiSnipsJumpForwardTrigger = "<Tab>"
"let g:UltiSnipsJumpBackwardTrigger = "<S-Tab>"

" Jump forward through snippet placeholders
" Note: UltiSnips#ExpandSnippetOrJump() returns 1 if it can expand or jump, 0 otherwise
" If it can't, it passes the Tab key through
imap <silent><expr> <Tab> UltiSnips#ExpandSnippetOrJump() ? '' : '<Tab>'
smap <expr> <Tab> UltiSnips#JumpForwards() ? '' : "\<Tab>"

" Jump backward through snippet placeholders
imap <expr> <S-Tab> UltiSnips#JumpBackwards() ? '' : "\<S-Tab>"
smap <expr> <S-Tab> UltiSnips#JumpBackwards() ? '' : "\<S-Tab>"


" =====================================
" ======== Tagbar Configuration =========
" =====================================

" Toggle Tagbar with F9
nnoremap <F9> :TagbarToggle<CR>

" =====================================
" ======== NERDCommenter Settings =======
" =====================================

" Configure NERDCommenter
let g:NERDSpaceDelims = 1
let g:NERDCompactSexyComs = 1
let g:NERDDefaultAlign = 'left'
let g:NERDTrimTrailingWhitespace = 1
let g:NERDCommenterUseOperatorMappings = 1

let g:NERDCommenterMapLeader = ''

" NERDCommenter Default Key Mappings:
" ,c<space>    - Toggle comment on current line or selection
" ,cc          - Comment current line or visually selected lines
" ,cu          - Uncomment current line or visually selected lines
" ,ci          - Invert comment state (toggle comment/uncomment)
" ,cs          - Use block comment for current line/selection
" ,cb          - Uncomment block comments
" ,cA          - Add comment at the end of the current line
" ,c$          - Add comment at the end of the current line (after code)
" ,cS          - Create "sexy" block comments (with extra formatting)
" ,ca          - Align comment delimiters with code
" ,c<Enter>    - Toggle comment with a new line added at the end

" =====================================
" ======== VHDL Formatting ============
" =====================================

" Function to format VHDL files using vsg
function! FormatVHDL()
    if executable('vsg')
        setlocal autoread
        let b:current_file = expand('%')
        write
        silent execute '!vsg -f ' . shellescape(b:current_file) . ' --fix'
        edit
        setlocal noautoread
    else
        echohl ErrorMsg | echo "Error: 'vsg' formatter not found." | echohl None
    endif
endfunction

" Map <leader>fv to format VHDL files
nnoremap <leader>fv :call FormatVHDL()<CR>

" =====================================
" ======== VHDL Language Settings ========
" =====================================

" Set indentation for VHDL files
autocmd FileType vhdl setlocal tabstop=2 shiftwidth=2 expandtab smartindent

" Automatically capitalize VHDL keywords
function! CapitalizeVHDLKeywords()
    let keywords = ['entity', 'architecture', 'signal', 'begin', 'end', 'if', 'then', 'else', 'process', 'is', 'port', 'map', 'use', 'library']
    for keyword in keywords
        execute 'silent! %s/\<' . keyword . '\>/' . toupper(keyword) . '/g'
    endfor
endfunction
autocmd BufWritePre *.vhdl call CapitalizeVHDLKeywords()

" Set comment style for VHDL
autocmd FileType vhdl setlocal comments=sr:--

" Align signals and assignments using vim-easy-align
nmap ga <Plug>(EasyAlign)
xmap ga <Plug>(EasyAlign)

" Remove trailing whitespace before saving VHDL files
autocmd BufWritePre *.vhdl %s/\s\+$//e

" Automatically close VHDL constructs
inoremap if if <Esc>lA then<Esc>o<Esc>oend if;
inoremap proc process(<Esc>li) is<Esc>o<Esc>oend process;

" =====================================
" ======== Color Scheme Cycling ========
" =====================================

" Define available color schemes
let g:color_schemes = [
\ '256_noir', 'abstract', 'afterglow', 'alduin', 'anderson', 'angr', 'apprentice',
\ 'archery', 'atom', 'ayu', 'carbonized-dark', 'carbonized-light', 'challenger_deep', 
\ 'deep-space', 'deus', 'dogrun', 'flattened_dark', 'flattened_light', 'focuspoint', 
\ 'fogbell_light', 'fogbell_lite', 'fogbell', 'github', 'gotham256', 'gotham', 
\ 'gruvbox', 'happy_hacking', 'hybrid_material', 'hybrid_reverse', 'hybrid', 'iceberg',
\ 'jellybeans', 'lightning', 'lucid', 'lucius', 'materialbox', 'meta5', 'minimalist',
\ 'molokai', 'molokayo', 'mountaineer-grey', 'mountaineer-light', 'mountaineer', 
\ 'nord', 'oceanic_material', 'OceanicNextLight', 'OceanicNext', 'one-dark', 'onedark', 
\ 'onehalfdark', 'onehalflight', 'one', 'orange-moon', 'orbital', 'paramount', 
\ 'parsec', 'pink-moon', 'purify', 'pyte', 'rdark-terminal2', 'scheakur', 'seoul256-light', 
\ 'seoul256', 'sierra', 'snow', 'solarized8_flat', 'solarized8_high', 'solarized8_low',
\ 'solarized8', 'sonokai', 'spacecamp_lite', 'spacecamp', 'space-vim-dark', 'stellarized',
\ 'sunbather', 'tender', 'termschool', 'twilight256', 'two-firewatch', 'wombat256mod', 
\ 'yellow-moon'
\ ]

" Initialize the current color scheme index
let g:current_color_scheme = 0

" Function to load a color scheme by index
function! LoadColorScheme(index)
    let g:current_color_scheme = a:index
    let color_scheme = g:color_schemes[g:current_color_scheme]
    try
        execute 'colorscheme ' . color_scheme
        echo "Color scheme set to " . color_scheme
    catch /^Vim\%((\a\+)\)\=:E185/
        echohl ErrorMsg | echo "Error: colorscheme " . color_scheme . " not found." | echohl None
    catch
        echohl ErrorMsg | echo "An unexpected error occurred while setting the color scheme." | echohl None
    endtry
endfunction

" Function to cycle through color schemes
function! CycleColorScheme(direction)
    if a:direction == 'next'
        let next_index = (g:current_color_scheme + 1) % len(g:color_schemes)
    elseif a:direction == 'prev'
        let next_index = (g:current_color_scheme - 1 + len(g:color_schemes)) % len(g:color_schemes)
    endif
    call LoadColorScheme(next_index)
endfunction

" Function to save the current color scheme as default
function! SaveColorSchemeToFile()
    let color_scheme = g:color_schemes[g:current_color_scheme]
    call writefile([color_scheme], expand('~/.vim/color_scheme.conf'))
    echo "Color scheme saved as default: " . color_scheme
endfunction

" Key mappings for cycling color schemes
nnoremap <leader>tp :call CycleColorScheme('prev')<CR>
nnoremap <leader>tn :call CycleColorScheme('next')<CR>
nnoremap <leader>ts :call SaveColorSchemeToFile()<CR>

" Load the saved color scheme if available
if filereadable(expand('~/.vim/color_scheme.conf'))
    let saved_color_scheme = trim(readfile(expand('~/.vim/color_scheme.conf'))[0])
    let index = index(g:color_schemes, saved_color_scheme)
    if index != -1
        let g:current_color_scheme = index
        call LoadColorScheme(g:current_color_scheme)
    endif
endif

" =====================================
" ======== CoC Extensions Installation ====
" =====================================

" Function to install CoC extensions if not already installed
function! InstallCoCExtensions()
    " Define desired extensions
    let extensions = ['coc-python', 'coc-sh', 'coc-json', 'coc-clangd', 'coc-html', 'coc-css', 'coc-tsserver', 'coc-textlab', 'coc-yaml', 'coc-markdownlint', 'coc-solargraph']

    " Iterate and install each extension
    for extension in extensions
        if empty(glob(expand('~/.config/coc/extensions/node_modules/') . extension))
            echo "Installing CoC extension: " . extension
            call system('cd ~/.config/coc/extensions && npm install ' . extension)
            if v:shell_error
                echohl ErrorMsg | echo "Failed to install CoC extension: " . extension | echohl None
            endif
        endif
    endfor
endfunction

" =====================================
" ======== vim-slime Settings =========
" =====================================

"Tell vim-slime to use tmux as the target
let g:slime_target = "tmux"

" Specify the tmux socket and target pane (tmux settings)
let g:slime_default_config = {"socket_name": "default", "target_pane": "{last}"}

xmap <leader><leader>s <Plug>SlimeRegionSend
nmap <leader><leader>s <Plug>SlimeParagraphSend

"let g:slime_paste_file = 1

" =====================================
" ======== EasyMotion Settings ============
" =====================================
let g:EasyMotion_do_mapping = 0 " Disable default mappings

" Jump to anywhere you want with minimal keystrokes, with just one key binding.
" `s{char}{label}`
"nmap s <Plug>(easymotion-overwin-f)
" or
" `s{char}{char}{label}`
" Need one more keystroke, but on average, it may be more comfortable.
nmap s <Plug>(easymotion-overwin-f2)

" Turn on case-insensitive feature
let g:EasyMotion_smartcase = 1

" JK motions: Line motions
map <Leader>j <Plug>(easymotion-j)
map <Leader>k <Plug>(easymotion-k)


" =====================================
" ======== Final Settings ============
" =====================================

" Ensure color schemes are loaded after all plugins
autocmd ColorScheme * highlight ExtraWhitespace ctermbg=red guibg=red

" Optional: Improve performance by disabling unused features
" set lazyredraw
" set noswapfile
" set nobackup
" set nowritebackup

" =====================================
" ======== Additional Mappings =========
" =====================================

" Generate and save the current buffer as Python executable script
" nnoremap <leader><leader>r :!python3 %:p<CR>

" Additional FZF key mappings (uncomment if needed)
" nnoremap <leader>b :Buffers<CR>
" nnoremap <leader>m :History<CR>
" nnoremap <leader>f :Files<CR>

" =====================================
" ========== Plugin Specific Configs =====
" =====================================

" === ALE Configuration (Already Defined Above) ====

" === CoC Configuration (Already Defined Above) ====

" === Copilot Configuration (Already Defined Above) ====

" === UltiSnips Configuration (Already Defined Above) ====

" === NERDCommenter Configuration (Already Defined Above) ====

" =====================================
" ========== End of vimrc ================
" =====================================
