local LiteUI = {}
LiteUI.Blueprints = {}

local Element = {}
Element.__index = Element

local function isInstance(val)
    return typeof(val) == "Instance"
end

local function isBlueprint(val)
    return typeof(val) == "table" and val._type == "blueprint"
end

local function cloneEverything(t, cache)
    if type(t) ~= "table" then
        return t
    end

    cache = cache or {}
    if cache[t] then
        return cache[t]
    end

    local copy = {}
    cache[t] = copy

    for key, value in pairs(t) do
        copy[cloneEverything(key, cache)] = cloneEverything(value, cache)
    end

    local mt = getmetatable(t)
    if type(mt) == "table" then
        setmetatable(copy, cloneEverything(mt, cache))
    elseif mt ~= nil then
        setmetatable(copy, mt)
    end

    return copy
end

function LiteUI.new(className, props)
    return Element.new(className, props, nil)
end

function LiteUI.Element(className, props, parent)
    return Element.new(className, props, parent)
end

function LiteUI.Blueprint(name, className, props)
    LiteUI.Blueprints[name] = {
        ["_type"] = "blueprint",
        BaseClass = className,
        Properties = props
    }
    return LiteUI.Blueprints[name]
end

function Element.new(className, props, parent)
    local self = setmetatable({}, Element)
    local blueprint = isBlueprint(className)
    
    if not blueprint then
        self.Instance = typeof(className) == "Instance" and className or Instance.new(className)
    elseif
        self.Instance = Instance.new(className.BaseClass)
    end
    
    self.Events = {}
    self._registered_events = {}
    
    if blueprint then
        local mutated = cloneEverything(className.Properties)
        if props then
            for k, v in pairs(props) do
                if k ~= "Children" and k ~= "Parent" then
                    mutated[k] = v
                elseif k == "Children" then
                    if not mutated.Children then mutated.Children = {} end
                    for childName, childData in pairs(v) do
                        mutated.Children[childName] = childData
                    end
                end
            end
        end
        self:Change(mutated)
    elseif props then
        self:Change(props)
    end
    
    if parent then self:Parent(parent) end
    
    return self
end

function Element:Element(className, props)
    return Element.new(className, props, self)
end

function Element:Parent(parent)
    if isInstance(parent) then
        self.Instance.Parent = parent
    else
        self.Instance.Parent = parent.Instance
    end
    return self
end

function Element:Event(name, fn)
    table.insert(self.Events, {name, fn})
    
    local found = false
    for _, con in ipairs(self._registered_events) do
        if con[1] == name then
            found = true
            break
        end
    end
    
    if not found then
        local con
        con = self.Instance[name]:Connect(function(...)
            for _, con in ipairs(self.Events) do
                if con[1] == name then
                    con[2](self, ...)
                end
            end
        end)
        table.insert(self._registered_events, {name, con})
    end
    return self
end

function Element:DisconnectEvents(eventName)
    if not eventName then
        self.Events = {}
        for _, con in ipairs(self._registered_events) do
            con[2]:Disconnect()
        end
        self._registered_events = {}
    else
        for i = #self.Events, 1, -1 do
            if self.Events[i][1] == eventName then
                table.remove(self.Events, i)
            end
        end
        for i = #self._registered_events, 1, -1 do
            local con = self._registered_events[i]
            if con[1] == eventName then
                con[2]:Disconnect()
                table.remove(self._registered_events, i)
            end
        end
    end
end

function Element:Change(props)
    for k, v in pairs(props) do
        if k == "Events" then
            for eve, nt in pairs(v) do
                self:Event(eve, nt)
            end
        elseif k == "Children" then
            for name, child in pairs(v) do
                if isInstance(child) then
                    child.Name = name
                    child.Parent = self.Instance
                elseif typeof(child) == "table" and child.Instance then
                    child.Instance.Name = name
                    child:Parent(self)
                elseif typeof(child) == "table" then
                    local created = Element.new(child[1], child[2], self)
                    created.Instance.Name = name
                end
            end
        else
            self.Instance[k] = v
        end
    end
    return self
end

function Element:Tween(goal, info, fn)
    local tw = game:GetService("TweenService"):Create(self.Instance, info, goal)
    if tw and fn then
        tw.Completed:Once(function(...)
            fn(self, ...)
        end)
    end
    tw:Play()
    return goal, tw
end

function Element:Destroy()
    self:DisconnectEvents()
    self.Instance:Destroy()
    
    self.Instance = nil
    self.Events = nil
    self._registered_events = nil
    setmetatable(self, nil)
end

LiteUI.Blueprint("CircleTextButton", "TextButton", {
    Size = UDim2.fromOffset(60, 60),
    ClipsDescendants = true,
    Children = {
        Constraint = {"UIAspectRatioConstraint", { AspectRatio = 1 }},
        Corner = {"UICorner", { CornerRadius = UDim.new(1, 0) }}
    }
})

LiteUI.Blueprint("CircleImageButton", "ImageButton", {
    Size = UDim2.fromOffset(60, 60),
    ClipsDescendants = true,
    Children = {
        Constraint = {"UIAspectRatioConstraint", { AspectRatio = 1 }},
        Corner = {"UICorner", { CornerRadius = UDim.new(1, 0) }}
    }
})

LiteUI.Blueprint("HoverTextButton", "TextButton", {
    Events = {
        MouseEnter = function(self)
            self:Tween(
                {Size = UDim2.new(self.Instance.Size.X.Scale + 0.04, self.Instance.Size.X.Offset, self.Instance.Size.Y.Scale + 0.04, self.Instance.Size.Y.Offset)},
                TweenInfo.new(0.1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
            )
        end,
        MouseLeave = function(self)
            self:Tween(
                {Size = UDim2.new(self.Instance.Size.X.Scale - 0.04, self.Instance.Size.X.Offset, self.Instance.Size.Y.Scale - 0.04, self.Instance.Size.Y.Offset)},
                TweenInfo.new(0.1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
            )
        end
    }
})

LiteUI.Blueprint("HoverImageButton", "ImageButton", {
    Events = {
        MouseEnter = function(self)
            self:Tween(
                {Size = UDim2.new(self.Instance.Size.X.Scale + 0.04, self.Instance.Size.X.Offset, self.Instance.Size.Y.Scale + 0.04, self.Instance.Size.Y.Offset)},
                TweenInfo.new(0.1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
            )
        end,
        MouseLeave = function(self)
            self:Tween(
                {Size = UDim2.new(self.Instance.Size.X.Scale - 0.04, self.Instance.Size.X.Offset, self.Instance.Size.Y.Scale - 0.04, self.Instance.Size.Y.Offset)},
                TweenInfo.new(0.1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
            )
        end
    }
})

return LiteUI