vim9script

# Display a warning message
export def WarnMsg(msg: string)
  :echohl WarningMsg
  :echomsg msg
  :echohl None
enddef

# Display an error message
export def ErrMsg(msg: string)
  :echohl Error
  :echomsg msg
  :echohl None
enddef

# Lsp server trace log directory
var lsp_log_dir: string
if has('unix')
  lsp_log_dir = '/tmp/'
else
  lsp_log_dir = $TEMP .. '\\'
endif
var lsp_server_trace: bool = false

# Enable or disable LSP server trace messages
export def ServerTrace(trace_enable: bool)
  lsp_server_trace = trace_enable
enddef

# Log a message from the LSP server. stderr is true for logging messages
# from the standard error and false for stdout.
export def TraceLog(stderr: bool, msg: string)
  if !lsp_server_trace
    return
  endif
  if stderr
    writefile(split(msg, "\n"), lsp_log_dir .. 'lsp_server.err', 'a')
  else
    writefile(split(msg, "\n"), lsp_log_dir .. 'lsp_server.out', 'a')
  endif
enddef

# Empty out the LSP server trace logs
export def ClearTraceLogs()
  if !lsp_server_trace
    return
  endif
  writefile([], lsp_log_dir .. 'lsp_server.out')
  writefile([], lsp_log_dir .. 'lsp_server.err')
enddef

# Convert a LSP file URI (file://<absolute_path>) to a Vim file name
export def LspUriToFile(uri: string): string
  # Replace all the %xx numbers (e.g. %20 for space) in the URI to character
  var uri_decoded: string = substitute(uri, '%\(\x\x\)',
				'\=nr2char(str2nr(submatch(1), 16))', 'g')

  # File URIs on MS-Windows start with file:///[a-zA-Z]:'
  if uri_decoded =~? '^file:///\a:'
    # MS-Windows URI
    uri_decoded = uri_decoded[8 : ]
    uri_decoded = uri_decoded->substitute('/', '\\', 'g')
  # On GNU/Linux (pattern not end with `:`)
  elseif uri_decoded =~? '^file:///\a'
    uri_decoded = uri_decoded[7 : ]
  endif

  return uri_decoded
enddef

# Returns if the URI refers to a remote file (e.g. ssh://)
# Credit: vim-lsp plugin
export def LspUriRemote(uri: string): bool
  return uri =~# '^\w\+::' || uri =~# '^[a-z][a-z0-9+.-]*://'
enddef

# Convert a Vim filename to an LSP URI (file://<absolute_path>)
def ConvertFilenameToUri(fname: string): string
  var uri: string = fnamemodify(fname, ':p')

  var on_windows: bool = false
  if uri =~? '^\a:'
    on_windows = true
  endif

  if on_windows
    # MS-Windows
    uri = uri->substitute('\\', '/', 'g')
  endif

  uri = uri->substitute('\([^A-Za-z0-9-._~:/]\)',
			'\=printf("%%%02x", char2nr(submatch(1)))', 'g')

  if on_windows
    uri = 'file:///' .. uri
  else
    uri = 'file://' .. uri
  endif

  return uri
enddef

# FIXME: Remove this function once the Vim bug (calling one exported function
# from another exported function in an autoload script is not working) is
# fixed. Replace the calls to this function directly with calls to
# ConvertFilenameToUri().
export def LspFileToUri(fname: string): string
  return ConvertFilenameToUri(fname)
enddef

# Convert a Vim buffer number to an LSP URI (file://<absolute_path>)
export def LspBufnrToUri(bnr: number): string
  return ConvertFilenameToUri(bnr->bufname())
enddef

# Returns the byte number of the specified LSP position in buffer 'bnr'.
# LSP's line and characters are 0-indexed.
# Vim's line and columns are 1-indexed.
# Returns a zero-indexed column.
export def GetLineByteFromPos(bnr: number, pos: dict<number>): number
  var col: number = pos.character
  # When on the first character, we can ignore the difference between byte and
  # character
  if col > 0
    # Need a loaded buffer to read the line and compute the offset
    if !bnr->bufloaded()
      bnr->bufload()
    endif

    var ltext: list<string> = bnr->getbufline(pos.line + 1)
    if !ltext->empty()
      var bidx = ltext[0]->byteidx(col)
      if bidx != -1
	return bidx
      endif
    endif
  endif

  return col
enddef

# push the current location on to the tag stack
export def PushCursorToTagStack()
  settagstack(winnr(), {items: [
			 {
			   bufnr: bufnr(),
			   from: getpos('.'),
			   matchnr: 1,
			   tagname: expand('<cword>')
			 }]}, 't')
enddef

# vim: shiftwidth=2 softtabstop=2
