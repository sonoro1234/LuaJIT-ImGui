-- //	TextEditor - A syntax highlighting text editor for ImGui
-- //	Copyright (c) 2024-2026 Johan A. Goossens. All rights reserved.
-- //
-- //	This work is licensed under the terms of the MIT license.
-- //	For a copy, see <https://opensource.org/licenses/MIT>.




-- //
-- //	Notifications
-- //
-- //	This class provides a "toast" notification system. Customers only have to Add
-- //	notification by providing a type, message and a dismissal time in microseconds
-- //	(the default is 400ms or 4 seconds).
-- //
-- //	Notifications show up as a stack growing from the bottom to the top. Older
-- //	messages will fade out and collapse. The user simply calls the Render method
-- //	every frame with a bottom left coordinate in viewport space and this will update
-- //	the lifecycle of each notification an render the stack.
local insert,remove = table.insert,table.remove

	--// a single notification
	-- struct Notification {
		-- // constructor
local id = 0
local Types = {
		success=1,
		warning=2,
		error=3,
		info=4
	};
local Phase = {
			fadeIn=1,
			wait=2,
			fadeOut=3,
			ghost=4,
			expired=5
};
local ig
local function U32(a,b,c,d)
	return ig.ImVec4(a/255,b/255,c/255,d/255)
end
--// properties
local fadeInDuration = 0.400;
local fadeOutDuration = 0.400;
local ghostDuration = 0.300;
local function Notification(type,message,dismissTime)
			
			local N = {}
			local name = "Notification"..tostring(id)
			id = id + 1
			
			local title, titleColor
			if type==Types.success then
					title = "Success";
					titleColor = U32(0.0, 255.0, 0.0, 255.0);
			elseif type==Types.warning then
					title = "Warning";
					titleColor = U32(255.0, 255.0, 0.0, 255.0);
			elseif type==Types.error then
					title = "Error";
					titleColor = U32(255.0, 0.0, 0.0, 255.0);
			elseif type==Types.info then
					title = "Info";
					titleColor = U32(0.0, 157.0, 255.0, 255.0);
			else
				error"bad notification Type"
			end
			N.title = title
			N.titleColor = titleColor
			
			local fadeInStart = ig.GetTime();
			local waitStart = fadeInStart + fadeInDuration;
			local fadeOutStart = waitStart + dismissTime;
			local ghostStart = fadeOutStart + fadeOutDuration;
			local expiredStart = ghostStart + ghostDuration;
		

		--// update the notification state
		function N:update() 
			--// get current time
			local now = ig.GetTime();

			--// update phase
			if (now >= expiredStart) then
				self.phase = Phase.expired;

			elseif (now >= ghostStart) then
				self.phase = Phase.ghost;

			elseif (now >= fadeOutStart) then
				self.phase = Phase.fadeOut;

			elseif (now >= waitStart) then
				self.phase = Phase.wait;

			else 
				self.phase = Phase.fadeIn;
			end

			--// determine transparency
			--using dmilliseconds = std::chrono::duration<float, std::milli>;
			local phase = self.phase
			local alpha
			if (phase == Phase.fadeIn) then
				alpha = (now - fadeInStart) / fadeInDuration;

			elseif (phase == Phase.wait) then
				alpha = 1.0;

			elseif (phase == Phase.fadeOut) then
				alpha = 1.0 - ((now - fadeOutStart) / fadeOutDuration);

			else 
				alpha = 0.0;
			end

			self.titleColor.w = alpha;
			self.alpha = alpha
			--// update ghost height (if required)
			if (phase == Phase.ghost) then
				ghostHeight = (1.0 - ((now - ghostStart) / ghostDuration)) * height;
			end
		end

		--// render a notification
		function N:render(pos, offset) 
			if (self.phase == Phase.ghost) then
				offset = offset + ghostHeight + ig.GetStyle().ItemSpacing.y;

			else 
				ig.PushStyleVar(ig.lib.ImGuiStyleVar_Alpha, self.alpha);
				ig.SetNextWindowBgAlpha(self.alpha);
				ig.SetNextWindowPos(ig.ImVec2(pos.x, pos.y - offset), ig.lib.ImGuiCond_Always, ig.ImVec2(1.0, 1.0));

				local flags = bit.bor(
					ig.lib.ImGuiWindowFlags_NoSavedSettings ,
					ig.lib.ImGuiWindowFlags_NoDecoration ,
					ig.lib.ImGuiWindowFlags_NoNav ,
					ig.lib.ImGuiWindowFlags_NoBringToFrontOnFocus ,
					ig.lib.ImGuiWindowFlags_NoFocusOnAppearing)

				ig.Begin(name, nil, flags);
				ig.BringWindowToDisplayFront(ig.GetCurrentWindow());

				ig.PushStyleColor(ig.lib.ImGuiCol_Text, self.titleColor);
				ig.AlignTextToFramePadding();
				ig.Text("%s", title);
				ig.PopStyleColor();

				local buttonWidth = ig.CalcTextSize("x").x + ig.GetStyle().FramePadding.x * 2.0;
				ig.SameLine(ig.GetCursorPosX() + ig.GetContentRegionAvail().x - buttonWidth);

				if (ig.Button("x")) then
					expiredStart = ig.GetTime();
				end

				ig.PushTextWrapPos(ig.GetMainViewport().Size.x / 4.0);
				ig.AlignTextToFramePadding();
				ig.Text("%s", message);
				ig.PopTextWrapPos();

				height = ig.GetWindowHeight();
				offset = offset + height + ig.GetStyle().ItemSpacing.y;

				ig.End();
				ig.PopStyleVar();
			end

			return offset;
		end

		N.name = name
		N.phase = phase
		--N.title = title
		N.message = message
		-- N.titleColor;
		-- float alpha;
		-- float height;
		-- float ghostHeight;

		N.fadeInStart = fadeInStart
		N.waitStart = waitStart
		N.fadeOutStart = fadeOutStart
		N.ghostStart = ghostStart
		N.expiredStart = expiredStart
		
		return N
end --Notification

local function Notifications(imgui)
	ig = imgui
	local M = {notifications={}}
	--// notifications types
	M.Type = Types

	--// constructor
	--Notifications() {}

	--// add a new notification
	function M:Add(type, message, dismissTime)
		dismissTime = dismissTime or 4
		insert(self.notifications,Notification(type, message, dismissTime));
	end

	--// render notifications as a stack (position is bottom-right of stack in viewport space)
	function M:Render(pos) 
		--// update state of all notifications
		for i,notification in ipairs(self.notifications) do
			notification:update();
		end

		--// remove expired notifications
		local to_remove = {}
		for i,notification in ipairs(self.notifications) do
			if notification.phase == Phase.expired then
				insert(to_remove,i)
			end
		end
		for i=#to_remove,1,-1 do remove(self.notifications,i) end
		
		--// render remaining notifications
		local offset = 0.0;

		for i,notification in ipairs(self.notifications) do
			offset = notification:render(pos, offset);
		end
	end
	return M
end

return Notifications
