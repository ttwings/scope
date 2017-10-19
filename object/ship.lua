local ship = class("ship")

ship.force_front = 100
ship.torque = 1000


ship.fire_cd = 0.1
ship.armor_max = 100
ship.shield_max = 100
ship.heat_max = 100
ship.cool_down_effect = 50
ship.tag = "ship"
ship.slot = {
	core = {
		{offx = 0,offy = 0,rot = 0,enabled = true}
	},
	universal = {
		{offx = 0.3, offy = -0.3, rot = 1/24,enabled = true},
		{offx = -0.3, offy = -0.3, rot = -1/24,enabled = true},
		{offx = 0, offy = -0.8, rot = 0,enabled = true},
		{offx = 0, offy = 0.4, rot = 0,enabled = true},
	},
	engine = {
		{offx = -0.2, offy = 0.5, rot = 1,enabled = true},
		{offx = 0.2, offy = 0.5, rot = 1,enabled = true},
	},
}
local Puff = require "object/puff"
local Weapon = require "object/weapon"
local Fragment = require "object/fragment"
local Explosion = require "object/explosion"
local KeyCore = require "object/key_core"

local Engine = require "object/engine"
local Shield = require "object/shield"

ship.linearDamping = 0.5
function ship:init(team,x,y,scale,rotation)
	self.team =team
	self.x = x
	self.y = y
	self.scale = scale
	self.angle = 0
	self.shape = love.physics.newCircleShape(0,0,scale)
	self.body = love.physics.newBody(game.world, x, y, "dynamic")
	self.fixture = love.physics.newFixture(self.body, self.shape,0.1)
	self.fixture:setUserData(self)
	self.armor = 5
	self.shield = 60
	self.heat = 50
	self.body:setAngularDamping(2)
	self.body:setLinearDamping(1)
	self.fire_timer = self.fire_cd
	table.insert(game.objects,self)
	self.slot = table.copy(ship.slot)
	self:add_plugin(Weapon,1)
	self:add_plugin(Weapon,2)
	self:add_plugin(Weapon,3)
	self:add_plugin(KeyCore,1)
	self:add_plugin(Engine,1)
	self:add_plugin(Engine,2)
	self:add_plugin(Shield,4)
	self.shield_coverage = 0.3
	self.showBar = false
end

function ship:update(dt)
	if self.destroyed then return end
	self:sync()
	self:cool_down(dt)	
	self:slot_update(dt)
end

local function inRect(x,y,rx,ry,rw,rh)
	return x>= rx and x<rx+rw and y>=ry and y<ry+rh 
end

function ship:inScreen()
	return inRect(self.x,self.y,game.cam:getVisible(2))
end

function ship:draw()
	if not self:inScreen() then return end 
	if self.showBar then self:drawBar() end
	love.graphics.push()
	love.graphics.translate(self.x, self.y)
	love.graphics.rotate(self.angle)
	self:drawBody()
	self:drawSlot()
	self:drawShield()
	love.graphics.pop()
end

function ship:destroy()
	self.destroyed = true
	self.body:destroy()
	self:makeFragment()
	self:makeExplosion()
	game.cam:shake()
	table.removeItem(game.enemies,self)
end

function ship:makeExplosion()
	if not self:inScreen() then return end
	for i = 1,5 do 
		delay:new((i-1)*0.1,function()Explosion(
			self.x-love.math.random()*10*i+5*i,
			self.y-love.math.random()*10*i+5*i,self.scale/i,5)end)
	end
end

function ship:sync()
	self.x,self.y = self.body:getPosition()
	self.angle = self.body:getAngle()
	self.body:setLinearDamping(self.linearDamping)
	self.openFire = false
	self.openShield = false
	self.sidePower = 0
	self.pushPower = 0
	self.turnPower = 0
	self.shieldPower = 0
end

function ship:slot_update(dt)
	for i,slot in ipairs(self.slot.engine) do
		if slot.enabled and slot.plugin then 
			local s,t,p = slot.plugin:update(dt)
			
		end
	end
	for i,slot in ipairs(self.slot.core) do
		if slot.enabled and slot.plugin then 
			slot.plugin:update(dt)
		end
	end
	for i,slot in ipairs(self.slot.universal) do
		if slot.enabled and slot.plugin then 
			slot.plugin:update(dt)
		end
	end
end


function ship:check_overheat()
	if self.heat>=self.heat_max then
		self.heat = self.heat_max
		self.overheat = true
		self.openFire = false
	end
end

function ship:add_plugin(plugin,position)
	
	local slot = self.slot[plugin.stype][position]
	slot.plugin = plugin(self,slot)

end

function ship:cool_down(dt)
	self.heat = self.heat - dt*self.cool_down_effect
	if self.heat<0 then self.heat=0 ; self.overheat = false end
end

function ship:makePuff()
	if love.math.random()>0.1 then return end
	if not self:inScreen() then return end
	for i,slot in ipairs(self.slot.engine) do
		local x,y = math.axisRot(slot.offx*self.scale,-slot.offy*self.scale,self.angle+slot.rot*Pi)
		Puff(self.x+x,self.y+y)
		self.heat = self.heat + 0.2
	end
end

function ship:getCanvas()
	local canvas = love.graphics.newCanvas(self.scale*3,self.scale*3)
	canvas:renderTo(function()
		love.graphics.setColor(255, 255, 255, 255)
		--love.graphics.rectangle("fill",0,0,self.scale*2,self.scale*2)
		love.graphics.push()
		love.graphics.translate(self.scale*1.5, self.scale*1.5)
		love.graphics.rotate(self.angle)
		self:drawBody()
		self:drawSlot()
		love.graphics.pop()
	end)
	return canvas
end

function ship:makeFragment()
	if not self:inScreen() then return end
	self.canvas = self:getCanvas()
	local fragments = Fragment(self.x,self.y,self.angle,self.canvas)
	self.canvas = nil
end


function ship:push(a)
	a = a or 1
	local dt = love.timer.getDelta()
	self.body:applyLinearImpulse(a *self.pushPower*math.sin(self.angle)*dt,
		-a*self.pushPower*math.cos(self.angle)*dt)
	self:makePuff()
end

function ship:turn(a)
	a = a or 1
	local dt = love.timer.getDelta()
	self.body:applyAngularImpulse(-a*self.turnPower*dt)
	self:makePuff()
end

function ship:side(a)
	a = a or 1
	local dt = love.timer.getDelta()
	self.body:applyLinearImpulse(-a*self.sidePower*math.cos(self.angle)*dt,
		-a*self.sidePower*math.sin(self.angle)*dt)
	self:makePuff()
end

function ship:stop(anti)
	self.body:setLinearDamping(3)
end

function ship:ai(dt)
	
end

function ship:drawBar()
	love.graphics.setColor(50, 255, 50, 50)
	love.graphics.rectangle("fill", self.x-self.scale, self.y-self.scale-20, self.scale*2, 5)
	love.graphics.setColor(50, 255, 50, 255)
	love.graphics.rectangle("fill", self.x-self.scale, self.y-self.scale-20, self.scale*2*self.armor/self.armor_max, 5)
	love.graphics.setColor(255, 55, 250, 50)
	love.graphics.rectangle("fill", self.x-self.scale, self.y-self.scale-15, self.scale*2, 5)
	love.graphics.setColor(255, 55, 250, 255)
	love.graphics.rectangle("fill", self.x-self.scale, self.y-self.scale-15, self.scale*2*self.shield/self.shield_max, 5)
	love.graphics.setColor(255, 255, 0, 50)
	love.graphics.rectangle("fill", self.x-self.scale, self.y-self.scale-10, self.scale*2, 5)
	love.graphics.setColor(255, 255, 0, 255)
	love.graphics.rectangle("fill", self.x-self.scale, self.y-self.scale-10, self.scale*2*self.heat/self.heat_max, 5)
end

function ship:drawBody()
	
	love.graphics.setColor(150, 50, 255, 255)
	local len = self.scale
	love.graphics.polygon("line", 
		0,-len,
		len,len,
		0,len/3,
		-len,len)
	if self.overheat then
		love.graphics.setColor(255, 0, 0, 150)
	else
		love.graphics.setColor(150, 50, 255, 150)
	end
	love.graphics.polygon("fill", 
		0,-len,
		len,len,
		0,len/3,
		-len,len)
end

local function oneSlot(x,y)
	local slot_size = 10
	love.graphics.rectangle("fill",  - slot_size/2,  - slot_size/2, slot_size, slot_size)
	love.graphics.setColor(255, 255, 255, 250)
	love.graphics.polygon("fill", 0, - slot_size/2, - slot_size/3, slot_size/3, slot_size/3,slot_size/3)
end


function ship:drawShield()
	if not self.openShield or self.shieldPower == 0 then return end

	local function to_cut()
		love.graphics.circle("fill", 0, 
			self.scale*2 - 0.5*self.scale/(1-(self.shield_coverage*0.4+0.35)), 
			self.scale/(self.shield_coverage*0.4+0.35))
	end
	love.graphics.stencil(to_cut, "replace", 1)

    love.graphics.setStencilTest("less", 1)
 
    love.graphics.setColor(100, 100, 255, 150)
    love.graphics.circle("fill", 0, 0, self.scale*1.5)
 	
    love.graphics.setStencilTest()

end

function ship:drawSlot()

	local len = self.scale
		
	for i,slot in ipairs(self.slot.core) do
		love.graphics.push()
		love.graphics.translate(slot.offx*len,slot.offy*len)
		love.graphics.rotate(slot.rot*Pi)
		love.graphics.setColor(255, 0, 0, 150)
		oneSlot()
		love.graphics.pop()
	end
	for i,slot in ipairs(self.slot.universal) do
		love.graphics.push()
		love.graphics.translate(slot.offx*len,slot.offy*len)
		love.graphics.rotate(slot.rot*Pi)
		love.graphics.setColor(0, 255, 0, 150)
		oneSlot()
		love.graphics.pop()
	end
	for i,slot in ipairs(self.slot.engine) do
		love.graphics.push()
		love.graphics.translate(slot.offx*len,slot.offy*len)
		love.graphics.rotate(slot.rot*Pi)
		love.graphics.setColor(0, 0, 255, 150)
		oneSlot()
		love.graphics.pop()
	end
end

function ship:damage(damage_point,damage_type)
	self.armor = self.armor - damage_point
	if self.armor<0 then self:destroy() end
	if damage_type == "structure" then

	elseif damage_type == "energy" then

	elseif damage_type == "quantum" then

	end
end

function ship:damage_shield()

end

function ship:damage_armor()

end




return ship