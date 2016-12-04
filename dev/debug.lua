--  
--
-- デバッグ
--
--

-- フック
function dev.hook_disp(p,l)
	local msg=":"
	local fname = debug.getinfo(2).name
	if fname~=nil then
		msg=msg..fname
	end
	if l~=nil then
		msg=msg..":"..tostring(l)
	end
	dev.print("[hook]"..p..msg)
end
function dev.hook_call()
	debug.sethook(dev.hook_disp, "c")
	--debug.sethook(dev.hook_disp, "r")
end
function dev.hook_line()
	debug.sethook(function(p,l)
		local d=debug.getinfo(2)
		local spath=d.source
		dev.print( spath..":"..tostring(d.currentline) )		
	end, "l")
end

--[[
	引数を検証する

	値, とりうる型名, [必要なメンバ名]
	dev.assert( c, {{ Eval = "function" }} )
	dev.assert( val, "table" )
	dev.assert( num )
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
-- devの
--
function dev.debug_index_impl(tbl, key)
	local v=rawget(tbl, key)
	if v==nil then
		local n=rawget(tbl,"__classname")
		dev.print("dev."..n," nil index ",key)
	end
	return v
end
function dev.debug_class_newindex_impl(tbl, key, val)
	local v=rawget(tbl,key)
	if v==nil then
		local n=rawget(tbl,"__classname")
		dev.print("dev."..n," nil newindex ",key)
	end
	return rawset(tbl, key, val)
end

-- classへの変更（追加・代入）を検知する
function dev.debug_class_index(...)
	dev.debug_index = {...}
end

