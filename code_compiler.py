import os

# Configuration
PROJECT_ROOT = "."  # Current directory
OUTPUT_FILE = "flutter_full_codebase.txt"

# Flutter relevant extensions
EXTENSIONS = {".dart", ".yaml"} 

# Directories to skip to avoid massive generated or system files
EXCLUDE_DIRS = {
    "build", 
    ".dart_tool", 
    ".gradle", 
    ".idea", 
    "android", 
    "ios", 
    "web", 
    "linux", 
    "macos", 
    "windows",
    ".git"
}

def bundle_codebase():
    with open(OUTPUT_FILE, "w", encoding="utf-8") as outfile:
        outfile.write("FLUTTER PROJECT CODEBASE BUNDLE\n")
        outfile.write("Generated for Gemini Analysis\n")
        
        for root, dirs, files in os.walk(PROJECT_ROOT):
            # Skip excluded directories
            dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
            
            for file in files:
                if any(file.endswith(ext) for ext in EXTENSIONS):
                    file_path = os.path.join(root, file)
                    
                    # Header for Gemini to distinguish files
                    outfile.write(f"\n\n{'='*60}\n")
                    outfile.write(f"PATH: {file_path}\n")
                    outfile.write(f"{'='*60}\n\n")
                    
                    try:
                        with open(file_path, "r", encoding="utf-8") as infile:
                            outfile.write(infile.read())
                    except Exception as e:
                        outfile.write(f"// Error reading file: {e}\n")

    print(f"✅ Success! Your Flutter codebase is bundled in: {OUTPUT_FILE}")

if __name__ == "__main__":
    bundle_codebase()