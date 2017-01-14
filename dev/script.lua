--
--==========================================================
--
-- スクリプト初期化コード
--
--==========================================================
-- 
dev.card_init_class = dev.new_class(
{
	__init = function( self, func, cdata )
		self.func = func
		self.cdata = cdata
	end,
	
	RegisterToCard = function( self, c )
		setmetatable( self, { __index = c } )
		self.func( c, self )
	end,
})
dev.CardInitClass = function( f, cd )
	return dev.card_init_class( f, cd )
end

-- 
-- スクリプトごとのモジュールオブジェクトを作成
--
dev.script_module = dev.new_class(
{
	__init = function( self, cdata )
		self.__idx  = {}
		self.effect = { __idx=self.__idx, __pfx="effect", __buildfn=dev.BuildEffectClass, }
		self.card   = { __idx=self.__idx, __pfx="card", __buildfn=dev.CardInitClass, }
		self.cdata  = cdata
		self.__init = {}
		
		setmetatable( self.effect, self.__mt )
		setmetatable( self.card, self.__mt )
	end,
	
	__mt = {
		__newindex = function( tbl, key, val )
			if rawget( tbl, key )==nil then
				local ent={ type=tbl.__pfx, name=key }
				if type(val)=="table" then -- ビルド済み
					ent.built = true
				end
				rawset( tbl.__idx, #tbl.__idx+1, ent ) 
			end
			rawset( tbl, key, val )
		end
	},
})

--
-- カードスクリプト
--
dev.BuildScript = function( script )
	local fn, class
	for _, entry in ipairs( script.__idx ) do
		local cur = script[entry.type]
		if entry.isbuilt then
			class = cur[entry.name]
		else
			fn = cur[entry.name]
			class = cur.__buildfn( fn, script.cdata )
			cur[entry.name] = class
		end
		table.insert( script.__init, class )
	end
	-- initial_effectを提供
	return function( c ) 
		dev.InitCard( script, c )
	end
end

-- 構築されたスクリプトをカードに対して実行する
dev.InitCard = function( script, c )
	for _, initer in ipairs( script.__init ) do 
		initer:RegisterToCard(c)
	end
end

-- 
-- スクリプトモジュール
--
dev.BuildScriptModule = function( mod )
	if dev.is_class( mod, dev.script_module ) then
		dev.BuildScript( mod )
	end
	return mod
end





