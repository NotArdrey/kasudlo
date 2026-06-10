import zipfile
import re
import sys

def extract_tags(docx_path):
    with zipfile.ZipFile(docx_path) as docx:
        content = docx.read('word/document.xml').decode('utf-8')
    
    # Remove XML tags to get pure text
    text = re.sub(r'<[^>]+>', '', content)
    
    # Find all << tags >>
    tags = re.findall(r'<<.*?>>', text)
    
    # Print unique tags
    for tag in sorted(set(tags)):
        print(tag)

if __name__ == "__main__":
    extract_tags(sys.argv[1])
