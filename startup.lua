local completion = require "cc.shell.completion"
shell.setCompletionFunction("vim.lua", completion.build(completion.file))
