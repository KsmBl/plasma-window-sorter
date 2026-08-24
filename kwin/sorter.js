/*
    plasma-window-sorter - KWin scripting payload
    Tiles the windows of one output into an even layout.

    This file is a library: the caller (the patched org.kde.panel containment)
    prepends a header defining PWS_MODE, PWS_OUTPUT_NAME, PWS_OUTPUT_RECT,
    PWS_INCLUDE_MINIMIZED, PWS_TARGET_ASPECT and PWS_DEBUG before loading it
    into KWin.

    SPDX-License-Identifier: GPL-2.0-or-later
*/

(function () {
    "use strict";

    var MODE = (typeof PWS_MODE === "string") ? PWS_MODE : "optimal";
    var INCLUDE_MINIMIZED = (typeof PWS_INCLUDE_MINIMIZED !== "undefined") ? !!PWS_INCLUDE_MINIMIZED : false;
    var TARGET_ASPECT = (typeof PWS_TARGET_ASPECT === "number" && PWS_TARGET_ASPECT > 0) ? PWS_TARGET_ASPECT : 4 / 3;
    var DEBUG = (typeof PWS_DEBUG !== "undefined") ? !!PWS_DEBUG : false;
    var OUTPUT_NAME = (typeof PWS_OUTPUT_NAME === "string") ? PWS_OUTPUT_NAME : "";
    var OUTPUT_RECT = (typeof PWS_OUTPUT_RECT !== "undefined") ? PWS_OUTPUT_RECT : null;

    function log(msg) {
        if (DEBUG) {
            console.info("[plasma-window-sorter] " + msg);
        }
    }

    function contains(rect, x, y) {
        return x >= rect.x && x < rect.x + rect.width && y >= rect.y && y < rect.y + rect.height;
    }

    // The panel that was right-clicked tells us which screen it lives on, so the
    // windows of that screen get sorted even when the pointer is elsewhere.
    function pickOutput() {
        var outputs = workspace.screens || [];
        var i;
        if (OUTPUT_NAME) {
            for (i = 0; i < outputs.length; ++i) {
                if (outputs[i].name === OUTPUT_NAME) {
                    return outputs[i];
                }
            }
        }
        if (OUTPUT_RECT && typeof OUTPUT_RECT.width === "number" && OUTPUT_RECT.width > 0) {
            var cx = OUTPUT_RECT.x + OUTPUT_RECT.width / 2;
            var cy = OUTPUT_RECT.y + OUTPUT_RECT.height / 2;
            for (i = 0; i < outputs.length; ++i) {
                if (contains(outputs[i].geometry, cx, cy)) {
                    return outputs[i];
                }
            }
        }
        return workspace.activeScreen;
    }

    function sameDesktop(a, b) {
        if (a === b) {
            return true;
        }
        return !!(a && b && a.id !== undefined && a.id === b.id);
    }

    function onCurrentDesktop(window) {
        if (window.onAllDesktops) {
            return true;
        }
        var desktops = window.desktops || [];
        if (desktops.length === 0) {
            return true;
        }
        for (var i = 0; i < desktops.length; ++i) {
            if (sameDesktop(desktops[i], workspace.currentDesktop)) {
                return true;
            }
        }
        return false;
    }

    function onCurrentActivity(window) {
        var activities = window.activities || [];
        if (activities.length === 0) {
            return true; // on all activities
        }
        return activities.indexOf(workspace.currentActivity) !== -1;
    }

    function eligible(window, output) {
        if (!window || window.deleted || !window.managed) {
            return false;
        }
        if (!window.normalWindow || window.specialWindow || window.dock || window.desktopWindow) {
            return false;
        }
        if (window.skipTaskbar || window.skipPager || window.transient) {
            return false;
        }
        if (!window.moveable || !window.resizeable) {
            return false;
        }
        if (window.minimized && !INCLUDE_MINIMIZED) {
            return false;
        }
        if (!onCurrentDesktop(window) || !onCurrentActivity(window)) {
            return false;
        }
        if (output && window.output && window.output !== output && window.output.name !== output.name) {
            return false;
        }
        return true;
    }

    // Split `total` into `n` integer slices without leaving rounding gaps.
    function edges(start, total, n) {
        var result = [];
        for (var i = 0; i <= n; ++i) {
            result.push(start + Math.round(total * i / n));
        }
        return result;
    }

    // "Optimal": pick the column count whose cells come closest to a comfortable
    // aspect ratio, mildly penalising layouts that leave cells empty.
    function bestColumnCount(count, area) {
        var best = 1;
        var bestScore = Infinity;
        for (var cols = 1; cols <= count; ++cols) {
            var rows = Math.ceil(count / cols);
            var aspect = (area.width / cols) / (area.height / rows);
            var score = Math.abs(Math.log(aspect / TARGET_ASPECT)) + 0.15 * (rows * cols - count);
            if (score < bestScore - 1e-9) {
                bestScore = score;
                best = cols;
            }
        }
        return best;
    }

    // Cascade: one pile, every window the same size, offset by a title-bar-ish
    // step so each stays clickable. The pile restarts once it would run off the
    // work area, which keeps the windows large no matter how many there are.
    function cascadeRects(count, area) {
        var step = Math.max(24, Math.round(Math.min(area.width, area.height) * 0.035));
        var maxSpan = Math.min(area.width, area.height) * 0.45;
        var perRun = Math.min(count, Math.floor(maxSpan / step) + 1);
        var width = area.width - (perRun - 1) * step;
        var height = area.height - (perRun - 1) * step;
        var rects = [];
        for (var i = 0; i < count; ++i) {
            var slot = i % perRun;
            rects.push({
                x: area.x + slot * step,
                y: area.y + slot * step,
                width: width,
                height: height,
            });
        }
        return rects;
    }

    function layoutRects(count, area, mode) {
        var rects = [];
        var i, r, c;

        if (mode === "cascade") {
            return cascadeRects(count, area);
        }

        if (mode === "vertical") {
            // Every window spans the full width, stacked top to bottom.
            var ys = edges(area.y, area.height, count);
            for (i = 0; i < count; ++i) {
                rects.push({ x: area.x, y: ys[i], width: area.width, height: ys[i + 1] - ys[i] });
            }
            return rects;
        }

        if (mode === "horizontal") {
            // Every window spans the full height, side by side.
            var xs = edges(area.x, area.width, count);
            for (i = 0; i < count; ++i) {
                rects.push({ x: xs[i], y: area.y, width: xs[i + 1] - xs[i], height: area.height });
            }
            return rects;
        }

        // optimal: a balanced grid that fills the whole work area
        var cols = bestColumnCount(count, area);
        var rows = Math.ceil(count / cols);
        var base = Math.floor(count / rows);
        var extra = count % rows;
        var rowEdges = edges(area.y, area.height, rows);

        for (r = 0; r < rows; ++r) {
            var inRow = base + (r < extra ? 1 : 0);
            var colEdges = edges(area.x, area.width, inRow);
            for (c = 0; c < inRow; ++c) {
                rects.push({
                    x: colEdges[c],
                    y: rowEdges[r],
                    width: colEdges[c + 1] - colEdges[c],
                    height: rowEdges[r + 1] - rowEdges[r],
                });
            }
        }
        return rects;
    }

    function place(window, rect) {
        if (window.fullScreen) {
            window.fullScreen = false;
        }
        if (window.minimized) {
            window.minimized = false;
        }
        if (window.tile) {
            window.tile = null; // release custom tiling, it would fight our geometry
        }
        if (window.maximizeMode !== 0) {
            window.setMaximize(false, false);
        }
        window.frameGeometry = { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
    }

    function run() {
        var output = pickOutput();
        if (!output) {
            log("no output found, giving up");
            return;
        }

        var all = workspace.windowList();
        var windows = [];
        for (var i = 0; i < all.length; ++i) {
            if (eligible(all[i], output)) {
                windows.push(all[i]);
            }
        }

        if (windows.length === 0) {
            log("nothing to sort on " + output.name);
            return;
        }

        // Keep the on-screen order stable: reading order for stacked/grid
        // layouts, left-to-right for columns, bottom-to-top of the stack for
        // the cascade (so whatever was on top stays on top).
        var byColumns = (MODE === "horizontal");
        if (MODE === "cascade") {
            windows.sort(function (a, b) {
                return a.stackingOrder - b.stackingOrder;
            });
        } else {
            windows.sort(function (a, b) {
                var ax = a.frameGeometry.x, ay = a.frameGeometry.y;
                var bx = b.frameGeometry.x, by = b.frameGeometry.y;
                if (byColumns) {
                    return (ax - bx) || (ay - by) || (a.internalId < b.internalId ? -1 : 1);
                }
                return (ay - by) || (ax - bx) || (a.internalId < b.internalId ? -1 : 1);
            });
        }

        var area = workspace.clientArea(KWin.MaximizeArea, output, workspace.currentDesktop);
        var rects = layoutRects(windows.length, area, MODE);

        log("mode=" + MODE + " output=" + output.name + " windows=" + windows.length + " area=" + JSON.stringify(area));
        for (var j = 0; j < windows.length; ++j) {
            log("  -> " + windows[j].caption + " " + JSON.stringify(rects[j]));
            place(windows[j], rects[j]);
            if (MODE === "cascade" && workspace.raiseWindow) {
                workspace.raiseWindow(windows[j]);
            }
        }
    }

    run();
})();
