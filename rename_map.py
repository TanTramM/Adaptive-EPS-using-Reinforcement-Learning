import os
import shutil
import re

base_dir = r"c:\Users\Admin\OneDrive\Desktop\git\Adaptive-EPS-using-Reinforcement-Learning"

def rename_dir(old, new):
    if os.path.exists(old):
        print(f"Renaming {old} to {new}")
        os.rename(old, new)

# 1. Rename directories
rename_dir(os.path.join(base_dir, 'Model', 'Map'), os.path.join(base_dir, 'Model', 'Map_6_8'))
rename_dir(os.path.join(base_dir, 'Result', 'Map'), os.path.join(base_dir, 'Result', 'Map_6_8'))
rename_dir(os.path.join(base_dir, 'Documents', 'Map'), os.path.join(base_dir, 'Documents', 'Map_6_8'))

# 2. Rename files
def rename_file(old, new):
    if os.path.exists(old):
        print(f"Renaming {old} to {new}")
        os.rename(old, new)

rename_file(os.path.join(base_dir, 'Model', 'load_map.m'), os.path.join(base_dir, 'Model', 'load_map_6_8.m'))
rename_file(os.path.join(base_dir, 'Model', 'Map_6_8', 'Map_s.mdl'), os.path.join(base_dir, 'Model', 'Map_6_8', 'Map_6_8_s.mdl'))
# Also rename any Model_Map_s.slxc or mdl in Model root
for f in os.listdir(os.path.join(base_dir, 'Model')):
    if f.startswith('Model_Map_s'):
        new_name = f.replace('Model_Map_s', 'Model_Map_6_8_s')
        rename_file(os.path.join(base_dir, 'Model', f), os.path.join(base_dir, 'Model', new_name))

# 3. Search and replace inside files
replacements = {
    r"'Map'": r"'Map_6_8'",
    r"\\Map\\": r"\\Map_6_8\\",
    r"/Map/": r"/Map_6_8/",
    r"load_map\(": r"load_map_6_8(",
    r"load_map\b": r"load_map_6_8",
    r"Map_s\.mdl": r"Map_6_8_s.mdl",
    r"Model_Map_s": r"Model_Map_6_8_s",
}

# files to check
extensions = ['.m', '.txt', '.md', '.json']

def process_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        try:
            with open(filepath, 'r', encoding='windows-1252') as f:
                content = f.read()
        except:
            return
            
    new_content = content
    for pattern, repl in replacements.items():
        new_content = re.sub(pattern, repl, new_content)
        
    if new_content != content:
        print(f"Updating {filepath}")
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)

for root, dirs, files in os.walk(base_dir):
    if '.git' in root or 'slprj' in root:
        continue
    for file in files:
        if any(file.endswith(ext) for ext in extensions):
            process_file(os.path.join(root, file))

print("Done.")
