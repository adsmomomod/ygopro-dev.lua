--
-- =====================================================================
--
--  !! Pie 場所の空きをチェック
--
-- =====================================================================
--
--
-- シミュレートのたびに生成される
--
dev.pie_counter = dev.new_class(
{
	__init = function( self, pie )
		self.pie = pie
	end,
	Reset = function( self, est )
		self.count = self.pie:Count( est )
	end,
	Check = function( self )	
		return self.count >= 0
	end,	
	Consume = function( self, v )
		self.count = self.count - v
	end,	
	Get = function( self )
		return self.count
	end,
})

--
-- 食べたり戻したりする側
--
dev.pie_consumer = dev.new_class(
{
	__init = function( self, piekey )
		self.piekey = piekey
	end,
	Update = function( self, est, cnt )
		local c=est:GetPieCounter(self.piekey)
		if c then
			c:Consume(cnt)
		else
			dev.print("ID=",self.piekey,"のパイが見つかりません")
		end
	end, 
	Get = function( self, est )
		local c=est:GetPieCounter(self.piekey)
		return c:Get()
	end,
})

dev.pie_releaser = dev.new_class(dev.pie_consumer
{
	__init = function( self, piekey )
		dev.super_init( self, piekey )
	end,
	Update = function( self, est, cnt )
		dev.super_class(self).Update( self, est, -cnt )
	end, 
})

--
-- パイの原型
--

-- 固定数のパイ
dev.basic_pie = dev.new_class(
{
	__init = function( self, cnt )
		self.key = 0
		self.maxcnt = cnt
	end,
	Count = function( self, est )
		return dev.eval( self.maxcnt, est )
	end,
	Consumer = function( self ) return dev.pie_consumer( self.key ) end,
	Releaser = function( self ) return dev.pie_releaser( self.key ) end,
})

-- モンスターゾーン / 魔法罠ゾーン
dev.zone_pie = dev.new_class(dev.basic_pie, 
{
	__init = function( self, loc )
		dev.super_init( self )
		self.location = loc
	end,
	Count = function( self, est )
		local p, l = dev.eval( self.location, est ):GetHead()
		return Duel.GetLocationCount( p, l )
	end,	
})

