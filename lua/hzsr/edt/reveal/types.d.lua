-- hzsr.edt.reveal.Reveal

---@alias hzsr.edt.reveal.Reveal.confirm_result "yes"|"no"|"cancel"

---@class hzsr.edt.reveal.Reveal.confirm_opts
---@field default? hzsr.edt.reveal.Reveal.confirm_result
---@field explicit_cancel? boolean

---@class hzsr.edt.reveal.Reveal.opts
---@field mode? hzsr.edt.reveal.mode
---@field hl? string
---@field async? boolean

---@class hzsr.edt.reveal.Reveal
---@field get_mode fun(self: hzsr.edt.reveal.Reveal): hzsr.edt.reveal.mode
---@field get_buf fun(self: hzsr.edt.reveal.Reveal): integer?
---@field get_win fun(self: hzsr.edt.reveal.Reveal): integer?
---@field activate fun(self: hzsr.edt.reveal.Reveal): boolean
---@field deactivate fun(self: hzsr.edt.reveal.Reveal): boolean
---@field is_active fun(self: hzsr.edt.reveal.Reveal): boolean
---@field is_valid fun(self: hzsr.edt.reveal.Reveal): boolean
---@field ask fun(self: hzsr.edt.reveal.Reveal, prompt: string, default?: string, completion?: string): string?
---@field choose fun(self: hzsr.edt.reveal.Reveal, prompt: string, items: string[], default?: integer): integer?
---@field confirm fun(self: hzsr.edt.reveal.Reveal, prompt: string, opts?: hzsr.edt.reveal.Reveal.confirm_opts): hzsr.edt.reveal.Reveal.confirm_result
