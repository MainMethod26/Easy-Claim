import re

def rewrite_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # We need to find showModalBottomSheet( ... builder: (ctx) => WIDGET );
    # And replace it with Navigator.push( ... builder: (ctx) => Scaffold( ... body: WIDGET ) );
    
    # We will use a parser that counts parentheses to find the end of the showModalBottomSheet call.
    
    idx = 0
    while True:
        idx = content.find("showModalBottomSheet(", idx)
        if idx == -1:
            break
            
        # find 'builder: ' after idx
        builder_idx = content.find("builder:", idx)
        if builder_idx == -1:
            idx += 1
            continue
            
        # find the arrow '=>' after builder
        arrow_idx = content.find("=>", builder_idx)
        if arrow_idx == -1:
            idx += 1
            continue
            
        # the widget starts after '=>'
        widget_start = arrow_idx + 2
        
        # now we need to find the end of the showModalBottomSheet call.
        # it ends when the parenthesis opened at idx is closed.
        open_parens = 0
        in_string = False
        string_char = ''
        end_idx = -1
        
        for i in range(idx, len(content)):
            c = content[i]
            if not in_string:
                if c == "'" or c == '"':
                    in_string = True
                    string_char = c
                elif c == '(':
                    open_parens += 1
                elif c == ')':
                    open_parens -= 1
                    if open_parens == 0:
                        end_idx = i
                        break
            else:
                if c == string_char and content[i-1] != '\\':
                    in_string = False
                    
        if end_idx == -1:
            idx += 1
            continue
            
        # The widget string is from widget_start to end_idx
        widget_str = content[widget_start:end_idx].strip()
        
        # We replace the whole showModalBottomSheet(...) with Navigator.push(...)
        replacement = f"""Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
          body: {widget_str},
        ),
      ),
    )"""
        
        content = content[:idx] + replacement + content[end_idx+1:]
        
        # adjust idx to not process the inserted content again
        idx = idx + len(replacement)

    with open(filepath, 'w') as f:
        f.write(content)

rewrite_file('lib/screens/easy_claim_home_screen.dart')
rewrite_file('lib/screens/support_screen.dart')
rewrite_file('lib/widgets/claims_wizard_modal.dart')

