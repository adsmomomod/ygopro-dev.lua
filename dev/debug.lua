--  
--
-- デバッグ用関数
--
--

-- 実行中の行を垂れ流す
function dev.hook_line()
	debug.sethook(function(p,l)
		local d=debug.getinfo(2)
		local spath=d.source
		dev.print( spath..":"..tostring(d.currentline) )
	end, "l")
end
function dev.hook_line_locals(lv)
	debug.sethook(function(p,l)
		local d=debug.getinfo(2)
		local spath=d.source
		dev.print( spath..":"..tostring(d.currentline) )
		dev.print_locals(2,2+lv)
	end, "l")	
end

-- 
function dev.print_locals(lv,lvmax)
	local lvstart=2+dev.option_arg(lv,0)
	lvmax=dev.option_arg(lvmax,999)
    -- レベルをめぐる
    for level=lvstart,lvmax do
        local d=debug.getinfo(level)
        if d==nil then
            break
        end
        dev.print("------ level-"..tostring(level).."("..tostring(d.linedefined)..") ---------------")
        
        -- ローカル変数を列挙
        local n=1
        local v
        for i=1,999 do
            n,v=debug.getlocal(level, i)
            if n==nil then
                break
            end
            dev.print( ">", n, " [", dev.typestr(v), "]" )
			if type(v)=="atable" then
				dev.print_table(v,n,0)
			else
				dev.print(v)
			end
	    end
		
		dev.print("")
    end
end

--[[
	引数を検証する

	値, とりうる型名/メンバ名テーブル
	dev.require( val, "number" )				= numberを要求
	dev.require( num )							= nilでないことを要求
	dev.require( c, {{ Eval = "function" }} )	= functionであるEvalというフィールドを持つテーブルを要求
	dev.require( val, {"number","userdata"} )	= numberまたはuserdataを要求
]]--
function dev.require_impl( val, typename, valname, cxt )
	if valname==nil then valname="" end 
	if cxt==nil then cxt={ dinfo=debug.getinfo(2), disp={} } end

	local valtype = dev.typestr(val)
					
	-- 型のチェック
	local expected = nil
	if typename==nil or typename==true then -- 主張：nilでない
		if val==nil then 
			expected = "not nil"
		end
	elseif type(typename) == "table" then
		local disptns={}
		local hit=false
		for i, tn in ipairs(typename) do
			if type(tn)=="table" then
				local all=true
				if type(val)=="table" then
					for name, types in pairs(tn) do
						if not dev.require_impl( val[name], types, name, cxt ) then 
							all=false 
							break
						end
					end
					hit=all
				end
				disptns[i]="table"
				if not all then
					valname=valname.." (member failed)"
				end
			else
				if valtype==tn then 
					hit=true 
					break 
				end
				disptns[i]=tn
			end
		end	
		if not hit then
			expected = table.concat( disptns, "|" )
		end
	elseif valtype~=typename then
		expected = typename
	end
	
	if expected~=nil then
		local disp="型の不一致 "..valname.." 期待:"..expected.." 現在:"..valtype
		dev.print( "[", cxt.dinfo.currentline, "] ", disp )
		return false
	else
		return true
	end
end

-- 検証を有効にする
function dev.enable_require()
	dev.print("require は ON です")
	dev.require = dev.require_impl
end
dev.require = function(...) return true end -- 普段はここに転送、なにもしない


--
-- 関数の実行を記録する
--
dev.hook_call = function(li)
	if li.std then
		li["Duel"]=Duel
		li["Card"]=Card
		li["Group"]=Group
		li["Effect"]=Effect
	end
	for name, val in pairs(li) do
		if type(val)=="table" or type(val)=="userdata" then
			local mname=dev.typestr(val)
			if tonumber(name)==nil then mname=name end
			dev.print(name)
			for k, v in pairs(val) do
				if type(v)=="function" then
					val[k]=dev.call_hook_proc(mname.."."..k, v)
				end
			end
		end
	end
end

local call_hook_stack = {
	Push = function(self, name)
		if self.lock then return false end
		
		local tail = self[#self]
		if tail==nil then
			table.insert( self, { level=0, indent="", name=name, ret={} } )
		else
			table.insert( self, { level=tail.level+1, indent=tail.indent.."|", name=name, ret={} } )
		end
		return true
	end,
	ValString = function(self, ...)
		local buf = table.pack(...)
		self.lock = true
		for i=1, buf.n do 
			buf[i]=dev.valstr(buf[i])
		end
		self.lock = false
		return table.concat(buf,", ")
	end,
	Params = function(self, ...)
		local cur=self[#self]
		return tostring(cur.level)..cur.indent.." "..cur.name.."( "..self:ValString(...).." )"
	end,
	Returns = function(self, ...)
		local cur=self[#self]
		cur.ret = table.pack(...)
		return tostring(cur.level)..cur.indent.." "..cur.name.." -> "..self:ValString(...)
	end,
	Pop = function(self, n)
		local temp_ret = dev.table.shallowcopy(self[#self].ret)
		self[#self] = nil
		return temp_ret
	end,
}

dev.call_hook_proc = function(name, fn)
	return function( ... )
		if call_hook_stack:Push(name) then
			dev.print( call_hook_stack:Params(...) )
			dev.print( call_hook_stack:Returns(fn(...)) )
			return table.unpack( call_hook_stack:Pop() )
		else
			return fn(...)
		end
	end
end



