

dev.single = {}

--
--
dev.single.player = dev.new_class(
{
	zones = { 
		"Deck", "Hand", "MZone", "SZone", 
		"Grave", "Removed", "Extra",
		"PZoneLeft", "PZoneRight", "Field", "ExtraP" 
	},

	__init = function( self, pid, args )
		self.pid=pid
		self.args=args
	end,
	
	Build = function( self )
		-- プレイヤーを登録
		Debug.SetPlayerInfo( self.pid, 
			dev.option_arg(self.args.life, 8000),
			dev.option_arg(self.args.turn, 0),
			dev.option_arg(self.args.draw, 0) )
		
		-- カードを登録
		local built = {}
		for _, ent in ipairs(self.args) do
			local fill=self[ent.zone_name.."Entry"]
			if fill then
				fill( self, ent )
				
				local l=built[ent.zone_name]
				if l==nil then l={} end 
				l.stack = ent.stack
				
				local offs=#l
				for k, code in pairs(ent) do
					local seq=tonumber(k)
					if seq then
						if ent.stack then seq=seq+offs end
						l[seq]={
							dev.option_arg(ent.owner, self.pid), 
							self.pid, 
							ent.zone, 
							dev.option_arg(ent.defseq, seq-1), 
							dev.option_arg(ent.pos, ent.defpos),
							ent.proc,
							code = code,
						}
					end
				end
				
				built[ent.zone_name] = l
			end
		end
		
		--
		for k, ent in pairs(built) do
			local ecnt=#ent
			for i, params in ipairs(ent) do
				local code = dev.option_val(ent.stack, ent[ecnt-i+1].code, params.code)
				Debug.AddCard( code, table.unpack(params) )
			end
		end
	end,
	
	-- 
	MZoneEntry = function( self, entry )
		entry.zone = LOCATION_MZONE
		entry.defpos = POS_FACEUP_ATTACK
		entry[5]=nil
	end,
	SZoneEntry = function( self, entry )
		entry.zone = LOCATION_SZONE
		entry.defpos = POS_FACEDOWN
		entry[8]=nil
	end,
	HandEntry = function( self, entry )
		entry.zone = LOCATION_HAND
		entry.defpos = POS_FACEDOWN
		entry.stack = true
	end,
	DeckEntry = function( self, entry )
		entry.zone = LOCATION_DECK
		entry.defpos = POS_FACEDOWN
		entry.stack = true
	end,
	GraveEntry = function( self, entry )
		entry.zone = LOCATION_GRAVE
		entry.defpos = POS_FACEUP
		entry.stack = true
	end,
	RemovedEntry = function( self, entry )
		entry.zone = LOCATION_REMOVED
		entry.defpos = POS_FACEUP	
		entry.stack = true	
	end,
	ExtraEntry = function( self, entry )
		entry.zone = LOCATION_EXTRA
		entry.defpos = POS_FACEDOWN
		entry.stack = true
	end,
	ExtraPEntry = function( self, entry )
		entry.zone = LOCATION_EXTRA
		entry.defpos = POS_FACEUP
		entry.stack = true
	end,
	FieldEntry = function( self, entry )
		entry.zone = LOCATION_SZONE
		entry.defpos = POS_FACEUP
		entry.defseq = 5
		entry[2]=nil
	end,
	PZoneLeftEntry = function( self, entry )
		entry.zone = LOCATION_SZONE
		entry.defpos = POS_FACEUP
		entry.defseq = 6
		entry[2]=nil
	end,
	PZoneRightEntry = function( self, entry )
		entry.zone = LOCATION_SZONE
		entry.defpos = POS_FACEUP
		entry.defseq = 7
		entry[2]=nil
	end,
})

--
--
dev.single.duel = dev.new_class(
{
	__init = function( self, ainame, flags )
		self.ainame=ainame
		if flags==nil then self.flags=DUEL_ATTACK_FIRST_TURN+DUEL_SIMPLE_AI end
		self.ps = {}
		
		for _, name in ipairs(dev.single.player.zones) do
			self[name] = function( self, args )
				args.zone_name = name
				return args
			end
		end
	end,
	
	FirstPlayer = function( self, args )
		table.insert( self.ps, dev.single.player(0, args) )
	end,
	SecondPlayer = function( self, args )
		table.insert( self.ps, dev.single.player(1, args) )
	end,
	
	Build = function( self )
		Debug.SetAIName( self.ainame )
		
		Debug.ReloadFieldBegin( self.flags )
		for i, v in ipairs(self.ps) do
			v:Build()
		end
		Debug.ReloadFieldEnd()
	end,
	
	-- 開始
	Begin = function( self )
		self:Build()
	end,
	BeginPuzzle = function( self, msg )
		self:Build()
		if msg~=nil then
			Debug.ShowHint(msg)
		end
		aux.BeginPuzzle()
	end,
})

