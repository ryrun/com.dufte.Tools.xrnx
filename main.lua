--default first refernce in mcompare
local last_ref_value = 0.04
local global_edit_pos = nil

local function switch_reference(type)
    --search for master track
    for it, track in ipairs(renoise.song().tracks) do
        if track.type == renoise.Track.TRACK_TYPE_MASTER then
            --search for mcompare
            for id, device in ipairs(track.devices) do
                if device.name == "VST: MeldaProduction: MCompare" then
                    for ip, parameter in ipairs(device.parameters) do
                        if type == 0 then
                            if parameter.name == "Selected" then
                                if parameter.value > 0 then
                                    last_ref_value = parameter.value --save latest active reference
                                    renoise.song().tracks[it].devices[id].parameters[ip]:record_value(0)
                                else
                                    renoise.song().tracks[it].devices[id].parameters[ip]:record_value(last_ref_value)
                                end
                            end
                        else
                            if parameter.name == "Filter - Filter" then
                                if parameter.value > 0 then
                                    renoise.song().tracks[it].devices[id].parameters[ip]:record_value(0)
                                else
                                    renoise.song().tracks[it].devices[id].parameters[ip]:record_value(1)
                                end
                            end
                        end
                    end
                end
                if device.name == "VST: Plugin Alliance: ADPTR MetricAB" then
                    for ip, parameter in ipairs(device.parameters) do
                        if type == 0 then
                            if parameter.name == "AB Switch" then
                                if parameter.value > 0 then
                                    renoise.song().tracks[it].devices[id].parameters[ip]:record_value(0)
                                else
                                    renoise.song().tracks[it].devices[id].parameters[ip]:record_value(1)
                                end
                            end
                        else
                            -- maybe
                        end
                    end
                end
            end
        end
    end
end

local function openclose_span()
    --search for master track
    for it, track in ipairs(renoise.song().tracks) do
        if track.type == renoise.Track.TRACK_TYPE_MASTER then
            --search for mcompare
            for id, device in ipairs(track.devices) do
                if device.name == "VST: Voxengo: SPAN" then
                    if device.external_editor_visible then
                        device.external_editor_visible = false
                    else
                        device.external_editor_visible = true
                    end
                end
                if device.name == "VST: Plugin Alliance: ADPTR MetricAB" then
                    if device.external_editor_visible then
                        device.external_editor_visible = false
                    else
                        device.external_editor_visible = true
                    end
                end
            end
        end
    end
end

renoise.tool():add_keybinding {
    name = "Global:dufte Tools:Reference switch ...",
    invoke = function()
        switch_reference(0)
    end
}

renoise.tool():add_keybinding {
    name = "Global:dufte Tools:Filter switch ...",
    invoke = function()
        switch_reference(1)
    end
}

renoise.tool():add_keybinding {
    name = "Global:dufte Tools:Open / Close Analyzer ...",
    invoke = function()
        openclose_span()
    end
}

renoise.tool():add_menu_entry {
    name = "--- Main Menu:Tools:dufte Tools:Reference switch ...",
    invoke = function()
        switch_reference()
    end
}

renoise.tool():add_menu_entry {
    name = "--- Main Menu:Tools:dufte Tools:Filter switch ...",
    invoke = function()
        switch_reference()
    end
}

renoise.tool():add_menu_entry {
    name = "--- Main Menu:Tools:dufte Tools:Open / Close Analyzer ...",
    invoke = function()
        openclose_span()
    end
}

local function ContinueFromLastPosition()
    renoise.song().transport:stop()
    if renoise.song().transport.edit_mode then
        if not global_edit_pos then
            global_edit_pos = renoise.song().transport.edit_pos
        end
        renoise.song().transport:start_at(global_edit_pos)
    else
        renoise.song().transport:start_at(renoise.song().transport.edit_pos)
    end
end

local function isEditing()
    if renoise.song().transport.edit_mode then
        global_edit_pos = renoise.song().transport.edit_pos
    end
end

local function set_sequencer_notifier()
    if not renoise.song().transport.edit_mode_observable:has_notifier(isEditing) then
        renoise.song().transport.edit_mode_observable:add_notifier(isEditing)
    end
end

if not renoise.tool().app_new_document_observable:has_notifier(set_sequencer_notifier) then
    renoise.tool().app_new_document_observable:add_notifier(set_sequencer_notifier)
end

renoise.tool():add_keybinding {
    name = "Pattern Editor:dufte Tools:Play from last played Song pos ...",
    invoke = function()
        ContinueFromLastPosition()
    end
}

local function alignsampletobeat()
    local song = renoise.song()
    local sample = song.selected_sample
    local sample_buffer = sample.sample_buffer

    if (sample_buffer.has_sample_data) then
        local bpm = song.transport.bpm
        local lpb = song.transport.lpb
        local align_to_lines = 0

        local mpt = renoise.app():show_prompt(
                "Align sample to beat",
                "Select one of following sizes",
                { "8", "16", "32", "64", "96", "128", "256", "Cancel" }
        )

        if (mpt == "8") then
            align_to_lines = 8
        elseif (mpt == "16") then
            align_to_lines = 16
        elseif (mpt == "32") then
            align_to_lines = 32
        elseif (mpt == "64") then
            align_to_lines = 64
        elseif (mpt == "96") then
            align_to_lines = 96
        elseif (mpt == "128") then
            align_to_lines = 128
        elseif (mpt == "256") then
            align_to_lines = 256
        else
            return
        end

        if align_to_lines > 0 then
            local num_frames = sample_buffer.number_of_frames
            local num_channels = sample_buffer.number_of_channels
            local bit_depth = sample_buffer.bit_depth
            local sample_rate = sample_buffer.sample_rate
            local sample_data_1 = {}
            local sample_data_2 = {}
            local samples_per_beat = 60.0 / bpm * sample_rate
            local samples_per_line = samples_per_beat / lpb
            local selection_end = sample_buffer.selection_end
            local add_samples = (align_to_lines * samples_per_line) - selection_end

            for frame_idx = 1, num_frames do
                sample_data_1[frame_idx] = sample_buffer:sample_data(1, frame_idx)
                if (num_channels == 2) then
                    sample_data_2[frame_idx] = sample_buffer:sample_data(2, frame_idx)
                end
            end

            if add_samples > 0 then

                -- add silence before, so impakt will stay in sync with beat
                sample_buffer:delete_sample_data()
                sample_buffer:create_sample_data(sample_rate, bit_depth, num_channels, num_frames + add_samples)
                sample_buffer:prepare_sample_data_changes()
                for frame_idx = 1, num_frames do
                    sample_buffer:set_sample_data(1, frame_idx + add_samples, sample_data_1[frame_idx])
                    if (num_channels == 2) then
                        sample_buffer:set_sample_data(2, frame_idx + add_samples, sample_data_2[frame_idx])
                    end
                end
                sample_buffer:finalize_sample_data_changes()

                -- enable auto seek
                sample.autoseek = true
            else
                renoise.app():show_warning("End selection too long, Sample will not be truncated!")
            end
        end
    end
end

renoise.tool():add_menu_entry {
    name = "Sample Editor:Process:Align sample to beat ...",
    invoke = function()
        alignsampletobeat()
    end
}

local function fitsampletosync()
    local song = renoise.song()
    local sample = song.selected_sample
    local sample_buffer = sample.sample_buffer

    if (sample_buffer.has_sample_data) then
        local vb = renoise.ViewBuilder()
        local bpm_selector = vb:valuebox { min = 30, max = 250, value = 120 }
        local view = vb:vertical_aligner {
            margin = 10,
            vb:horizontal_aligner {
                spacing = 10,
                vb:vertical_aligner {
                    vb:text { text = 'BPM:' },
                    bpm_selector,
                },
            },
        }

        local res = renoise.app():show_custom_prompt(
                "Set sourc BPM",
                view,
                { 'Ok', 'Cancel' }
        );
        if res == 'Ok' then
            local num_frames = sample_buffer.number_of_frames
            local num_channels = sample_buffer.number_of_channels
            local bit_depth = sample_buffer.bit_depth
            local sample_rate = sample_buffer.sample_rate
            local sample_data_1 = {}
            local sample_data_2 = {}
            local bpm = bpm_selector.value
            local lpb = song.transport.lpb
            local samples_per_beat = 60.0 / bpm * sample_rate
            local samples_per_line = samples_per_beat / lpb
            local add_samples = 0

            local lines_in_sample = num_frames / samples_per_line
            local lines_in_sample_mod = num_frames % samples_per_line

            if lines_in_sample_mod > 0 then
                lines_in_sample = math.ceil(lines_in_sample)
                add_samples = lines_in_sample * samples_per_line - sample_buffer.number_of_frames

                for frame_idx = 1, num_frames do
                    sample_data_1[frame_idx] = sample_buffer:sample_data(1, frame_idx)
                    if (num_channels == 2) then
                        sample_data_2[frame_idx] = sample_buffer:sample_data(2, frame_idx)
                    end
                end

                sample_buffer:delete_sample_data()
                sample_buffer:create_sample_data(sample_rate, bit_depth, num_channels, num_frames + add_samples)
                sample_buffer:prepare_sample_data_changes()
                for frame_idx = 1, num_frames do
                    sample_buffer:set_sample_data(1, frame_idx, sample_data_1[frame_idx])
                    if (num_channels == 2) then
                        sample_buffer:set_sample_data(2, frame_idx, sample_data_2[frame_idx])
                    end
                end
                sample_buffer:finalize_sample_data_changes()
            end

            sample.beat_sync_enabled = true
            sample.beat_sync_lines = lines_in_sample
            sample.beat_sync_mode = renoise.Sample.BEAT_SYNC_PERCUSSION
            sample.autoseek = true
        end
    end
end

renoise.tool():add_menu_entry {
    name = "Sample Editor:Process:Fit sample to beat sync ...",
    invoke = function()
        fitsampletosync()
    end
}

local function doublecontentabove()
    local current_pattern = renoise.song().selected_pattern
    local current_patterntrack = renoise.song().selected_pattern_track
    local pattern_length = current_pattern.number_of_lines
    local edit_pos = renoise.song().transport.edit_pos
    local edit_pos_line = edit_pos.line - 1

    if edit_pos_line + 1 < pattern_length and edit_pos_line > 0 then
        for line_idx = 1, edit_pos_line do
            --copy content
            current_patterntrack:line(line_idx + edit_pos_line):copy_from(current_patterntrack:line(line_idx))
        end
        edit_pos.line = math.min(edit_pos.line + edit_pos_line, pattern_length)
        renoise.song().transport.edit_pos = edit_pos
    end
end

renoise.tool():add_menu_entry {
    name = "Pattern Editor:Duplicate content from above ...",
    invoke = function()
        doublecontentabove()
    end
}

renoise.tool():add_keybinding {
    name = "Pattern Editor:dufte Tools:Duplicate content from above ...",
    invoke = function()
        doublecontentabove()
    end
}

local function doublecontent()
    local current_pattern = renoise.song().selected_pattern
    local pattern_length = current_pattern.number_of_lines
    current_pattern.number_of_lines = pattern_length * 2
    for it, current_patterntrack in ipairs(current_pattern.tracks) do
        for line_idx = 1, pattern_length do
            current_patterntrack:line(line_idx + pattern_length):copy_from(current_patterntrack:line(line_idx))
        end
    end
end

renoise.tool():add_menu_entry {
    name = "Pattern Sequencer:Duplicate content ...",
    invoke = function()
        doublecontent()
    end
}

local function setloopcloudoutput()
    local t = renoise.song().selected_track
    local instruments = renoise.song().instruments

    for it, instrument in ipairs(instruments) do
        if instrument.name == "VST: Loopcloud ()" then
            local presetdata = instrument.plugin_properties.plugin_device.active_preset_data
            print(presetdata)
        end
    end

end

renoise.tool():add_menu_entry {
    name = "Pattern Editor:Set loopcloud audio output to this track ...",
    invoke = function()
        setloopcloudoutput()
    end
}