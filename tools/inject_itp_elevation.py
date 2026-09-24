import json
import os
import copy

REPO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ifp_json_path = r"C:\Users\cogli\.gemini\antigravity\scratch\ifp_height_extracted\base\gameplay\anim_graphs\player_base.animgraph.json"
itp_json_path = r"C:\Users\cogli\.gemini\antigravity\scratch\itp_extracted\base\gameplay\anim_graphs\player_base.animgraph.json"
out_dir = os.path.join(REPO_DIR, "source", "raw", "base", "gameplay", "anim_graphs")
os.makedirs(out_dir, exist_ok=True)
out_json_path = os.path.join(out_dir, "player_base.animgraph.json")

print("[*] Loading IFP and ITP graphs...")
with open(ifp_json_path, "r", encoding="utf-8") as f:
    ifp = json.load(f)
with open(itp_json_path, "r", encoding="utf-8") as f:
    itp = json.load(f)

# Find max handle in ITP
max_handle = 0
def get_max_h(o):
    global max_handle
    if isinstance(o, dict):
        if "HandleId" in o:
            try:
                max_handle = max(max_handle, int(o["HandleId"]))
            except:
                pass
        for v in o.values():
            get_max_h(v)
    elif isinstance(o, list):
        for x in o:
            get_max_h(x)

get_max_h(itp)
print(f"[*] ITP Max HandleId: {max_handle}")

# Collect handles in IFP
handles_ifp = {}
def collect_ifp(o):
    if isinstance(o, dict):
        if "HandleId" in o:
            handles_ifp[str(o["HandleId"])] = o
        for v in o.values():
            collect_ifp(v)
    elif isinstance(o, list):
        for x in o:
            collect_ifp(x)

collect_ifp(ifp)
orig_blend2 = handles_ifp["3734"]

# Deepcopy the original Blend2 node directly
blend2_clean = copy.deepcopy(orig_blend2)

# Collect handles in ITP
handles_itp = {}
def collect_itp(o):
    if isinstance(o, dict):
        if "HandleId" in o:
            handles_itp[str(o["HandleId"])] = o
        for v in o.values():
            collect_itp(v)
    elif isinstance(o, list):
        for x in o:
            collect_itp(x)

collect_itp(itp)
node_3903 = handles_itp["3903"]
orig_node_3904 = copy.deepcopy(node_3903["Data"]["inputLink"]["node"])
assert orig_node_3904.get("HandleId") == "3904", f"Expected 3904, got {orig_node_3904.get('HandleId')}"
print(f"[*] Successfully grabbed original node 3904: {orig_node_3904.get('Data', {}).get('$type')}")

# In blend2_clean, find leaf of Branch 1 (3741) and leaf of Branch 2 (3843)
def get_leaf_tb(tb_root):
    curr = tb_root
    while curr:
        d = curr.get("Data", curr)
        inp = d.get("inputNode", {})
        nxt = inp.get("node", {})
        if nxt.get("Data", {}).get("$type") == "animAnimNode_TranslateBone":
            curr = nxt
        else:
            return curr
    return curr

b1_root = blend2_clean["Data"]["firstInputNode"]["node"]
b2_root = blend2_clean["Data"]["secondInputNode"]["node"]

leaf_b1 = get_leaf_tb(b1_root)
leaf_b2 = get_leaf_tb(b2_root)

print(f"[*] Leaf B1 HandleId: {leaf_b1.get('HandleId')}")
print(f"[*] Leaf B2 HandleId: {leaf_b2.get('HandleId')}")

# Splice leaf of B1 to orig_node_3904
leaf_b1["Data"]["inputNode"] = {
    "$type": "animPoseLink",
    "node": orig_node_3904
}

# Splice leaf of B2 to HandleRefId 3904
leaf_b2["Data"]["inputNode"] = {
    "$type": "animPoseLink",
    "node": {
        "HandleRefId": "3904"
    }
}

# Set weight variable to foot_elevation_offset
weight_node = blend2_clean["Data"]["weightNode"]["node"]
weight_node["Data"]["variableName"]["$value"] = "foot_elevation_offset"

# Renumber ONLY the 30 injected nodes (3734..3741 and 3830..3851)
target_handles = set([str(x) for x in range(3734, 3742)] + [str(x) for x in range(3830, 3852)])
old_to_new_handles = {}
next_hid = max(max_handle + 100, 5000)

for h in sorted([int(x) for x in target_handles]):
    old_to_new_handles[str(h)] = str(next_hid)
    next_hid += 1

print(f"[*] Renumbering {len(old_to_new_handles)} nodes (from {next_hid - len(old_to_new_handles)} to {next_hid - 1})")

def renumber_injected(o):
    if isinstance(o, dict):
        # Do not descend into orig_node_3904 to avoid renumbering downstream nodes
        if o.get("HandleId") == "3904":
            return
        if "HandleId" in o:
            hid = str(o["HandleId"])
            if hid in old_to_new_handles:
                o["HandleId"] = old_to_new_handles[hid]
        if "HandleRefId" in o:
            ref = str(o["HandleRefId"])
            if ref in old_to_new_handles:
                o["HandleRefId"] = old_to_new_handles[ref]
        for v in o.values():
            renumber_injected(v)
    elif isinstance(o, list):
        for x in o:
            renumber_injected(x)

renumber_injected(blend2_clean)

# Now attach blend2_clean to node_3903's inputLink
print(f"[*] Attaching Blend2 node ({blend2_clean.get('HandleId')}) to Node 3903 inputLink...")
node_3903["Data"]["inputLink"] = {
    "$type": "animPoseLink",
    "node": blend2_clean
}

# Add variables to ITP root
root = itp["Data"]["RootChunk"]
v_dict = root["variables"]["Data"] if "Data" in root["variables"] else root["variables"]
float_vars = v_dict["floatVariables"]

has_var = any(v.get("Data", v).get("name", {}).get("$value") == "foot_elevation_offset" for v in float_vars)
if not has_var:
    var_hid = str(next_hid)
    next_hid += 1
    new_var = {
        "HandleId": var_hid,
        "Data": {
            "$type": "animAnimVariableFloat",
            "default": 0.5,
            "enableDebug": 0,
            "max": 1,
            "min": 0,
            "name": {
                "$type": "CName",
                "$storage": "string",
                "$value": "foot_elevation_offset"
            },
            "value": 0.5
        }
    }
    float_vars.append(new_var)
    print(f"[+] Added 'foot_elevation_offset' to floatVariables (HandleId: {var_hid})")

has_ifp = any(v.get("Data", v).get("name", {}).get("$value") == "ifp_height_blend" for v in float_vars)
if not has_ifp:
    ifp_hid = str(next_hid)
    next_hid += 1
    new_ifp_var = {
        "HandleId": ifp_hid,
        "Data": {
            "$type": "animAnimVariableFloat",
            "default": 0.5,
            "enableDebug": 0,
            "max": 1,
            "min": 0,
            "name": {
                "$type": "CName",
                "$storage": "string",
                "$value": "ifp_height_blend"
            },
            "value": 0.5
        }
    }
    float_vars.append(new_ifp_var)
    print(f"[+] Added 'ifp_height_blend' to floatVariables (HandleId: {ifp_hid})")

print(f"[*] Writing updated animgraph JSON to: {out_json_path} ...")
with open(out_json_path, "w", encoding="utf-8") as f:
    json.dump(itp, f, indent=2)

print("[+] Injection completed successfully!")
