// ----------------------
// content.js
// Hudl Playlist: stable final-order labeling + popup with autocomplete/export
// - On-page labels: "id, hh:mm - hh:mm" (IDs start at 1 and reflect final visual order)
// - Export: id|<period> , hh:mm - hh:mm|text
// ----------------------
alert("PLUGIN LOADED");

const EP_SELECTOR = "video-playlist-episode-title-text";
const STABLE_DELAY = 700;      // ms of no external changes before we label
const MAX_INITIAL_WAIT = 7000; // ms max initial wait before forcing a label

// ---------------- helpers ----------------
function qsAll(root, sel) {
    try { return Array.from((root || document).querySelectorAll("." + sel)); }
    catch (e) { return []; }
}
function extractTimeslot(str) {
    const m = (str || "").match(/(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})/);
    return m ? `${m[1]} - ${m[2]}` : "";
}
function extractPeriodText(str) {
    if (!str) return "";
    const m = str.match(/(\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2})/);
    if (!m) return str.trim();
    let left = str.slice(0, m.index).trim();
    left = left.replace(/[\s,|:\-–—]+$/g, "").replace(/\s+/g, " ");
    return left;
}

// try to find the playlist root by choosing the ancestor that contains most episode nodes
function findPlaylistRoot() {
    const all = qsAll(document, EP_SELECTOR);
    if (!all.length) return null;

    const counts = new Map();
    all.forEach(el => {
        let a = el.parentElement;
        let depth = 0;
        while (a && a !== document.body && depth < 10) {
            counts.set(a, (counts.get(a) || 0) + 1);
            a = a.parentElement;
            depth++;
        }
        // ensure direct parent counted
        if (el.parentElement) counts.set(el.parentElement, (counts.get(el.parentElement) || 0) + 1);
    });

    let best = null, bestCount = 0;
    counts.forEach((count, ancestor) => {
        if (count > bestCount) {
            bestCount = count;
            best = ancestor;
        }
    });

    if (best) return best;
    // fallback
    return all[0].parentElement || document.body;
}

// ---------------- core: label playlist in FINAL visual order ----------------
let relabelInProgress = false;
function relabelPlaylist(playlistRoot) {
    if (!playlistRoot) return;
    relabelInProgress = true;

    // get the nodes as they currently appear (visual DOM order)
    const nodes = qsAll(playlistRoot, EP_SELECTOR);

    // ensure we preserve original full label before overwriting
    const snapshot = [];
    for (let i = 0; i < nodes.length; i++) {
        const el = nodes[i];
        if (el.setAttribute && !el.getAttribute("data-original-title")) {
            el.setAttribute("data-original-title", el.innerText);
        }
        const original = el.getAttribute("data-original-title") || el.innerText;
        const timeslot = extractTimeslot(original);
        const periodText = extractPeriodText(original);

        // apply on-page label exactly as: "id, hh:mm - hh:mm"
        const label = `${i + 1}, ${timeslot || ""}`;
        // Only change if different (reduce DOM churn)
        if (el.innerText !== label) {
            try { el.innerText = label; }
            catch (e) { /* fallback silent */ }
        }

        snapshot.push({
            id: i + 1,
            periodText: periodText,
            timeslot: timeslot
        });
    }

    // store snapshot for popup/export (final visual order)
    relabelPlaylist.sortedSnapshot = snapshot;

    // Allow observer to ignore the short burst of mutations we caused
    setTimeout(() => { relabelInProgress = false; }, 80);
}

// ---------------- stability monitor & mutation observer ----------------
let playlistRoot = null;
let stableTimer = null;
let lastExternalMut = Date.now();

function scheduleRelabel() {
    clearTimeout(stableTimer);
    stableTimer = setTimeout(() => {
        if (relabelInProgress) { scheduleRelabel(); return; }
        playlistRoot = findPlaylistRoot();
        relabelPlaylist(playlistRoot);
    }, STABLE_DELAY);
}

// initial: wait for stability or force after MAX_INITIAL_WAIT
(function initialMonitor() {
    playlistRoot = findPlaylistRoot();
    const start = Date.now();
    const checkInterval = 200;
    const iv = setInterval(() => {
        // if no external mutation for STABLE_DELAY, relabel and stop
        if (Date.now() - lastExternalMut > STABLE_DELAY) {
            clearInterval(iv);
            playlistRoot = findPlaylistRoot();
            relabelPlaylist(playlistRoot);
            return;
        }
        if (Date.now() - start > MAX_INITIAL_WAIT) {
            clearInterval(iv);
            playlistRoot = findPlaylistRoot();
            relabelPlaylist(playlistRoot);
            return;
        }
    }, checkInterval);
})();

const observer = new MutationObserver((mutations) => {
    // if our own relabel in progress, ignore
    if (relabelInProgress) return;

    // If playlistRoot not found yet, try to find it
    if (!playlistRoot) playlistRoot = findPlaylistRoot();

    // determine if any mutation affects the playlist area (or adds episode nodes)
    let touched = false;
    for (const mut of mutations) {
        const t = mut.target;
        if (playlistRoot && playlistRoot.contains(t)) { touched = true; break; }
        if (mut.addedNodes && mut.addedNodes.length) {
            for (const n of mut.addedNodes) {
                if (n.nodeType === 1 && (n.classList && n.classList.contains(EP_SELECTOR) || n.querySelector && n.querySelector("." + EP_SELECTOR))) {
                    touched = true; break;
                }
            }
            if (touched) break;
        }
        if (mut.removedNodes && mut.removedNodes.length) {
            for (const n of mut.removedNodes) {
                if (n.nodeType === 1 && (n.classList && n.classList.contains(EP_SELECTOR))) {
                    touched = true; break;
                }
            }
            if (touched) break;
        }
    }
    if (!touched) return;

    lastExternalMut = Date.now();
    scheduleRelabel();
});

// Observe the whole body but we'll ignore events outside playlistRoot
observer.observe(document.body, { childList: true, subtree: true, characterData: true });

// Safety: try to label now if playlistRoot exists
playlistRoot = findPlaylistRoot();
if (playlistRoot) {
    setTimeout(() => relabelPlaylist(playlistRoot), 300);
}

// ---------------- Popup + autocomplete + export ----------------
function createPopup() {
    const popup = window.open("", "videoPopup",
        `width=400,height=560,left=${screen.availWidth - 420},top=50,scrollbars=yes,resizable=yes`
    );
    const body = popup.document.body;
    body.style.fontFamily = "Arial, sans-serif";
    body.style.backgroundColor = "#f5f5f5";
    body.style.padding = "0";
    body.style.margin = "0";

    body.innerHTML = `
        <table id="videoTable" border="1" cellpadding="8" cellspacing="0"
               style="width:auto; border-collapse:collapse; background:#fff; margin:10px;">
            <tr style="background-color:#4a90e2; color:#fff;">
                <th style="padding:10px 8px; text-align:center;">ID</th>
                <th style="padding:10px 8px; text-align:center;">Set Plays</th>
            </tr>
        </table>
    `;
    const table = popup.document.getElementById("videoTable");

    // Use the final snapshot (if recent relabel hasn't run yet, use findPlaylistRoot snapshot)
    const snapshot = (relabelPlaylist.sortedSnapshot || []).slice();

    // If snapshot empty, attempt to build quick snapshot from current DOM reading originals
    if (!snapshot.length) {
        const nodes = qsAll(playlistRoot || document, EP_SELECTOR);
        for (let i = 0; i < nodes.length; i++) {
            const el = nodes[i];
            const orig = el.getAttribute("data-original-title") || el.innerText;
            snapshot.push({
                id: i+1,
                periodText: extractPeriodText(orig),
                timeslot: extractTimeslot(orig)
            });
        }
    }

    snapshot.forEach((s, i) => {
        const row = table.insertRow();
        row.style.backgroundColor = i % 2 === 0 ? "#ffffff" : "#f8f9fa";
        row.style.borderBottom = "1px solid #dee2e6";

        const idCell = row.insertCell();
        idCell.style.padding = "6px 8px";
        idCell.style.fontWeight = "bold";
        idCell.style.textAlign = "center";
        idCell.innerText = i + 1;

        const cell = row.insertCell();
        cell.style.padding = "6px 8px";
        const input = popup.document.createElement("input");
        input.type = "text";
        input.style.width = "260px";
        input.style.padding = "6px 8px";
        input.style.border = "1px solid #ced4da";
        input.style.borderRadius = "4px";
        input.style.fontSize = "14px";
        input.dataset.index = i;
        cell.appendChild(input);
    });


    // Use existing row and cell if they already exist
    let br = table.insertRow();
    br.style.backgroundColor = "#f8f9fa";
    let bc = br.insertCell();
    bc.colSpan = 2;
    bc.style.padding = "12px 0";
    bc.style.textAlign = "center";
    bc.style.border = "none";

    // === ORANGE BUTTON: Generate TXT File ===
    const generateBtn = popup.document.createElement("button");
    generateBtn.innerText = "Generate File";
    generateBtn.style.backgroundColor = "orange";
    generateBtn.style.color = "white";
    generateBtn.style.padding = "8px 20px";
    generateBtn.style.border = "none";
    generateBtn.style.borderRadius = "4px";
    generateBtn.style.cursor = "pointer";
    generateBtn.style.width = "260px";
    bc.appendChild(generateBtn);

    // Spacer between buttons
    const spacer = popup.document.createElement("div");
    spacer.style.height = "8px";
    bc.appendChild(spacer);

    // === GRAY BUTTON: Download Organizer Script ===
    const downloadBtn = popup.document.createElement("button");
    downloadBtn.innerText = "Download MACOS Organizer Script";
    downloadBtn.style.backgroundColor = "#555";
    downloadBtn.style.color = "white";
    downloadBtn.style.padding = "6px 20px";
    downloadBtn.style.border = "none";
    downloadBtn.style.borderRadius = "4px";
    downloadBtn.style.cursor = "pointer";
    downloadBtn.style.width = "260px";
    bc.appendChild(downloadBtn);

    const downloadBtnW = popup.document.createElement("button");
    downloadBtnW.innerText = "Download Windows Organizer Script";
    downloadBtnW.style.backgroundColor = "#555";
    downloadBtnW.style.color = "white";
    downloadBtnW.style.padding = "6px 20px";
    downloadBtnW.style.border = "none";
    downloadBtnW.style.borderRadius = "4px";
    downloadBtnW.style.cursor = "pointer";
    downloadBtnW.style.width = "260px";
    downloadBtnW.style.marginTop = "10px";
    bc.appendChild(downloadBtnW);


    // ---------- autocomplete ----------
    let allTags = [];
    // try to load tags.json; non-blocking
    try {
        fetch(chrome.runtime.getURL('tags.json'))
            .then(r => r.json())
            .then(data => { allTags = (data.tags || []).map(t => t.name); })
            .catch(() => { allTags = []; });
    } catch (e) {
        allTags = [];
    }

    function setupAutocomplete() {
        const inputs = table.querySelectorAll("input");
        inputs.forEach(input => {
            input.addEventListener("input", function () {
                const val = this.value.toLowerCase();

                // 1. Collect values already used in other textboxes
                const existingValues = Array.from(inputs)
                    .filter(i => i !== this && i.value.trim() !== "")
                    .map(i => i.value.trim());

                // 2. Suggestions from tags.json that start with current text
                const tagSuggestions = allTags.filter(tag =>
                    tag.toLowerCase().startsWith(val) &&
                    !existingValues.some(ev => ev.toLowerCase() === tag.toLowerCase())
                );

                // 3. Suggestions from other textbox values that start with current text
                const reuseSuggestions = existingValues.filter(ev =>
                    ev.toLowerCase().startsWith(val)
                );

                // 4. Merge and deduplicate
                const allSuggestions = [...new Set([...reuseSuggestions, ...tagSuggestions])];

                const closeAll = () => {
                    const els = popup.document.getElementsByClassName("autocomplete-items");
                    while (els.length) els[0].remove();
                };
                closeAll();
                if (!val || allSuggestions.length === 0) return;

                const list = popup.document.createElement("div");
                list.classList.add("autocomplete-items");
                list.style.border = "1px solid #d4d4d4";
                list.style.position = "absolute";
                list.style.background = "#fff";
                list.style.zIndex = 9999;
                list.style.width = this.offsetWidth + "px";

                allSuggestions.forEach(s => {
                    const item = popup.document.createElement("div");
                    item.innerHTML = s;
                    item.style.padding = "2px 5px";
                    item.addEventListener("click", () => {
                        this.value = s;
                        closeAll();
                    });
                    list.appendChild(item);
                });

                this.parentNode.appendChild(list);

                let currentFocus = -1;
                this.addEventListener("keydown", function (e) {
                    const items = list.getElementsByTagName("div");
                    function addActive() {
                        if (!items) return;
                        for (let it of items) it.classList.remove("autocomplete-active");
                        if (currentFocus >= items.length) currentFocus = 0;
                        if (currentFocus < 0) currentFocus = items.length - 1;
                        items[currentFocus].classList.add("autocomplete-active");
                        items[currentFocus].style.background = "#e9e9e9";
                    }
                    if (e.keyCode === 40) { currentFocus++; addActive(); }
                    else if (e.keyCode === 38) { currentFocus--; addActive(); }
                    else if (e.keyCode === 13) {
                        e.preventDefault();
                        if (currentFocus > -1) items[currentFocus].click();
                    }
                });

                popup.document.addEventListener("click", () => closeAll());
            });
        });
    }

    setupAutocomplete();

    // ---------- export ----------
    generateBtn.addEventListener("click", () => {
        const lines = [];
        const rows = table.querySelectorAll("tr");
        let k = 0;
        for (let i = 1; i < rows.length; i++) {
            const tr = rows[i];
            if (tr.cells.length < 2) continue;
            const idCell = tr.cells[0];
            const inputEl = tr.cells[1].querySelector("input");
            if (!inputEl) continue;
            const id = idCell.innerText.trim();
            const text = inputEl.value || "";
            const snap = snapshot[k] || (relabelPlaylist.sortedSnapshot || [])[k] || { periodText: "", timeslot: "" };
            const period = snap.periodText || "";
            const times  = snap.timeslot || "";
            const middle = period && times ? `${period} , ${times}` : (period || times);
            lines.push(`${id}|${middle}|${text}`);
            k++;
        }
        const blob = new Blob([lines.join("\n")], { type: "text/plain" });
        const a = popup.document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = "video_text.txt";
        a.click();
    });

    downloadBtn.addEventListener("click", async () => {
        try {
            const url = "https://raw.githubusercontent.com/kamberserk/PlugInstat/main/macOS_scripts/1_Organize%20Videos/organize_videos.sh";

            // 1. fetch the script
            const resp = await fetch(url);
            if (!resp.ok) {
                alert("Could not download script (HTTP " + resp.status + ")");
                return;
            }

            // 2. turn it into a blob
            const text = await resp.text();
            const blob = new Blob([text], { type: "text/x-sh" });

            // 3. create a temporary download link
            const a = document.createElement("a");
            a.href = URL.createObjectURL(blob);
            a.download = "organize_videos.sh";
            a.style.display = "none";
            document.body.appendChild(a);

            // 4. click it programmatically
            a.click();

            // 5. cleanup
            document.body.removeChild(a);
            URL.revokeObjectURL(a.href);
        } catch (e) {
            console.error(e);
            alert("Download failed.");
        }
    });



    downloadBtnW.addEventListener("click", async () => {
        try {
            const url = "https://raw.githubusercontent.com/kamberserk/PlugInstat/main/windows_scripts/1_Organize%20Videos/organize_videos.bat";

            const resp = await fetch(url);
            if (!resp.ok) {
                alert("Could not download script (HTTP " + resp.status + ")");
                return;
            }

            const text = await resp.text();
            const blob = new Blob([text], { type: "application/octet-stream" }); // FIXED HERE

            const a = document.createElement("a");
            a.href = URL.createObjectURL(blob);
            a.download = "organize_videos.bat";
            a.style.display = "none";
            document.body.appendChild(a);

            a.click();

            document.body.removeChild(a);
            URL.revokeObjectURL(a.href);
        } catch (e) {
            console.error(e);
            alert("Download failed.");
        }
    });




}

// add button to page
const btn = document.createElement("button");
btn.innerText = "Open Popup";
btn.style.backgroundColor = "orange";
btn.style.color = "white";
btn.style.padding = "8px 12px";
btn.style.border = "none";
btn.style.cursor = "pointer";
btn.style.marginBottom = "10px";
document.body.insertBefore(btn, document.body.firstChild);
btn.addEventListener("click", createPopup);
