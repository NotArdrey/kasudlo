import re
path = r'e:\flutter-project\Kasudlo\lib\src\survey_schema.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
new_content = re.sub(r"textField\('name', 'Name'\)", r"familyNameField('name', 'Name')", content)
with open(path, 'w', encoding='utf-8') as f:
    f.write(new_content)
