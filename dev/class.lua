--
--
-- クラスのようななにかを提供
--
--

-- 新しいクラスを作成
function dev.new_class(basedefs, defs)
	local cls
	
	if basedefs~=nil and defs==nil then
		defs=basedefs
		basedefs=nil
	end
	
	-- 新規作成
	if basedefs==nil then
		cls = dev.option_arg(defs, {})
		cls.__is_class = 0
        
		if cls.__init==nil then
			cls.__init = function(self,...) end
        end
		
		local mt = {}
		dev.table.merge(mt, dev.class_mt)
		setmetatable(cls, mt)
		
	-- 基底クラスあり
	else
		cls = dev.table.deepcopy(basedefs)
		for k, v in pairs(defs) do
			cls[k] = v
		end
		
		cls.__is_class = 0
		cls.__super = basedefs
	end
	return cls
end
function dev.register_class( name, cls )
	rawset(cls, "__classname", name)
	rawset(cls, "__is_class", 1)
end

-- 新しいクラスを作成＋登録
--  :クラスをdevのフィールドにしない場合はこちらを使用すること
function dev.new_named_class( name, d1, d2 )
	local cls = dev.new_class( d1, d2 )
	dev.register_class( name, cls )
	return cls
end

-- スーパークラス
function dev.super_class(cls)
	if not dev.is_class(cls) then
		dev.print( type(cls), "はクラスではありません" )
		return nil
	end
	local sp=cls.__super
	if sp==nil then
		dev.print( cls.__classname, "にはスーパークラスがありません" )
		return nil
	end
	return sp
end
function dev.super_call( self, fname, ... )
	local sup=dev.super_class(self)
	-- 関数定義を取得
	local suf=sup[fname]
	if suf==nil then
		dev.print( "スーパークラス", sup.__classname, "には", fname, "がありません" )
		return nil
	end
	-- superを一時的に書き換え
	local olsup=self.__super
	self.__super = sup.__super
	local r=suf( self, ... ) -- 実行
	self.__super = olsup
	return r
end
function dev.super_init( self, ... )
	dev.super_call( self, "__init", ... )
end

-- クラスかどうか
function dev.is_class( tbl, name )
	if type(tbl)=="table" and tbl.__is_class~=nil then
		if name==nil then
			return true
		elseif dev.is_class( name ) then
			return tbl.__classname == name.__classname
		else
			return tbl.__classname == name
		end
	end
	return false
end

-- インスタンスを作成
function dev.instantiate( baseinst, cls, ... )
	local inst = baseinst
	for k, v in pairs(cls) do
		inst[k] = v
	end
	local t=dev.table.deepcopy(getmetatable(cls))
	t.__call = nil
	setmetatable( inst, t )
	
	inst:__init(...)
	
	if dev.debug_index~=nil then
		dev.table.addmeta( inst, dev.class_mt_d )
	end
	return inst
end
function dev.new( cls, ... )
	return dev.instantiate( {}, cls, ... )
end

-- クラス用メタテーブル
dev.class_mt = {
	__call = dev.new -- ()で構築
}

-- devにメタテーブルを設定：クラスなら勝手に名前を登録
setmetatable(dev, {
	__newindex = function( tbl, key, val )
		if dev_debug_newindex then
			dev.print( "dev.__newindex "..key )
		end
		if dev.is_class(val) and val.__is_class==0 and tbl[key] == nil then
			dev.register_class( key, val )
		end
		rawset( tbl, key, val )
	end
})
