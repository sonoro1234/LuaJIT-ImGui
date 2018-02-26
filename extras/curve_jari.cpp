/* To use, add this prototype somewhere.. 

namespace ImGui
{
	int Curve(const char *label, const ImVec2& size, int maxpoints, ImVec2 *points);
	float CurveValue(float p, int maxpoints, const ImVec2 *points);
};

*/
/*
	Example of use:

	ImVec2 foo[10];
	...
	foo[0].x = -1; // init data so editor knows to take it from here
	...
	if (ImGui::Curve("Das editor", ImVec2(600, 200), 10, foo))
	{
		// curve changed
	}
	...
	float value_you_care_about = ImGui::CurveValue(0.7f, 10, foo); // calculate value at position 0.7
*/


namespace ImGui
{

	float CurveValue(float p, int maxpoints, const ImVec2 *points)
	{
		if (maxpoints < 2 || points == 0)
			return 0;
		if (p < 0) return points[0].y;

		int left = 0;
		while (left < maxpoints && points[left].x < p && points[left].x != -1) left++;
		if (left) left--;

		if (left == maxpoints-1)
			return points[maxpoints - 1].y;

		float d = (p - points[left].x) / (points[left + 1].x - points[left].x);

		return points[left].y + (points[left + 1].y - points[left].y) * d;
	}

	int Curve(const char *label, const ImVec2& size, int maxpoints, ImVec2 *points)
	{
		int modified = 0;
		int i;
		if (maxpoints < 2 || points == 0)
			return 0;

		if (points[0].x < 0)
		{
			points[0].x = 0;
			points[0].y = 0;
			points[1].x = 1;
			points[1].y = 1;
			points[2].x = -1;
		}

		ImGuiWindow* window = GetCurrentWindow();
		ImGuiState& g = *GImGui;
		const ImGuiStyle& style = g.Style;
		const ImGuiID id = window->GetID(label);
		if (window->SkipItems)
			return 0;

		ImRect bb(window->DC.CursorPos, window->DC.CursorPos + size);
		ItemSize(bb);
		if (!ItemAdd(bb, NULL))
			return 0;

		const bool hovered = IsHovered(bb, id);

		int max = 0;
		while (max < maxpoints && points[max].x >= 0) max++;

		int kill = 0;
		do
		{
			if (kill)
			{
				modified = 1;
				for (i = kill + 1; i < max; i++)
				{
					points[i - 1] = points[i];
				}
				max--;
				points[max].x = -1;
				kill = 0;
			}

			for (i = 1; i < max - 1; i++)
			{
				if (abs(points[i].x - points[i - 1].x) < 1 / 128.0)
				{
					kill = i;
				}
			}
		}
		while (kill);


		RenderFrame(bb.Min, bb.Max, window->Color(ImGuiCol_FrameBg), true, style.FrameRounding);

		float ht = bb.Max.y - bb.Min.y;
		float wd = bb.Max.x - bb.Min.x;

		if (hovered)
		{
			SetHoveredID(id);
			if (g.IO.MouseDown[0])
			{
				modified = 1;
				ImVec2 pos = (g.IO.MousePos - bb.Min) / (bb.Max - bb.Min);
				pos.y = 1 - pos.y;				

				int left = 0;
				while (left < max && points[left].x < pos.x) left++;
				if (left) left--;

				ImVec2 p = points[left] - pos;
				float p1d = sqrt(p.x*p.x + p.y*p.y);
				p = points[left+1] - pos;
				float p2d = sqrt(p.x*p.x + p.y*p.y);
				int sel = -1;
				if (p1d < (1 / 16.0)) sel = left;
				if (p2d < (1 / 16.0)) sel = left + 1;

				if (sel != -1)
				{
					points[sel] = pos;
				}
				else
				{
					if (max < maxpoints)
					{
						max++;
						for (i = max; i > left; i--)
						{
							points[i] = points[i - 1];
						}
						points[left + 1] = pos;
					}
					if (max < maxpoints)
						points[max].x = -1;
				}


				// snap first/last to min/max
				points[0].x = 0;
				points[max - 1].x = 1;
			}
		}

		// bg grid
		window->DrawList->AddLine(
			ImVec2(bb.Min.x, bb.Min.y + ht / 2),
			ImVec2(bb.Max.x, bb.Min.y + ht / 2),
			window->Color(ImGuiCol_TextDisabled), 3);

		window->DrawList->AddLine(
			ImVec2(bb.Min.x, bb.Min.y + ht / 4),
			ImVec2(bb.Max.x, bb.Min.y + ht / 4),
			window->Color(ImGuiCol_TextDisabled));

		window->DrawList->AddLine(
			ImVec2(bb.Min.x, bb.Min.y + ht / 4 * 3),
			ImVec2(bb.Max.x, bb.Min.y + ht / 4 * 3),
			window->Color(ImGuiCol_TextDisabled));

		for (i = 0; i < 9; i++)
		{
			window->DrawList->AddLine(
				ImVec2(bb.Min.x + (wd / 10) * (i + 1), bb.Min.y),
				ImVec2(bb.Min.x + (wd / 10) * (i + 1), bb.Max.y),
				window->Color(ImGuiCol_TextDisabled));
		}	

		// lines
		for (i = 1; i < max; i++)
		{
			ImVec2 a = points[i - 1];
			ImVec2 b = points[i];
			a.y = 1 - a.y;
			b.y = 1 - b.y;
			a = a * (bb.Max - bb.Min) + bb.Min;
			b = b * (bb.Max - bb.Min) + bb.Min;
			window->DrawList->AddLine(a, b, window->Color(ImGuiCol_PlotLines));
		}

		if (hovered)
		{
			// control points
			for (i = 0; i < max; i++)
			{
				ImVec2 p = points[i];
				p.y = 1 - p.y;
				p = p * (bb.Max - bb.Min) + bb.Min;
				ImVec2 a = p - ImVec2(2, 2);
				ImVec2 b = p + ImVec2(2, 2);
				window->DrawList->AddRect(a, b, window->Color(ImGuiCol_PlotLines));
			}
		}

		RenderTextClipped(ImVec2(bb.Min.x, bb.Min.y + style.FramePadding.y), bb.Max, label, NULL, NULL, ImGuiAlign_Center);
		return modified;
	}

};