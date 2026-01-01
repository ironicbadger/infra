"""Custom filter to indent YAML list items under their parent keys."""


def get_indent(line):
    """Return the indentation level (number of leading spaces) of a line."""
    return len(line) - len(line.lstrip())


def is_list_key(line):
    """Check if line is a key that could start a list (ends with : but not ::)."""
    stripped = line.strip()
    return stripped.endswith(':') and not stripped.endswith('::')


def is_list_item(line):
    """Check if line is a YAML list item (starts with '- ')."""
    return line.lstrip().startswith('- ')


def indent_yaml_lists(content):
    """
    Transform YAML so list items are indented under their parent key.

    Before:
        environment:
        - FOO=bar
        volumes:
        - /data:/data

    After:
        environment:
          - FOO=bar
        volumes:
          - /data:/data

    Also handles list items that are dicts:
    Before:
        configs:
        - source: test
          target: /etc/test

    After:
        configs:
          - source: test
            target: /etc/test
    """
    lines = content.split('\n')
    result = []
    in_list_block = False
    list_base_indent = 0

    for line in lines:
        stripped = line.lstrip()
        current_indent = get_indent(line)

        # Check if previous line was a key that could start a list
        if result and not in_list_block:
            prev_line = result[-1]
            if is_list_key(prev_line):
                prev_indent = get_indent(prev_line)
                # If this line is a list item at the same indent level
                if is_list_item(line) and current_indent == prev_indent:
                    in_list_block = True
                    list_base_indent = prev_indent

        if in_list_block:
            # Check if we've left the list block
            if stripped and not is_list_item(line) and current_indent <= list_base_indent:
                in_list_block = False
                result.append(line)
            elif is_list_item(line) and current_indent == list_base_indent:
                # List item - add 2 spaces
                result.append(' ' * (list_base_indent + 2) + stripped)
            elif current_indent == list_base_indent and stripped:
                # Continuation of list item dict - add 2 spaces
                result.append(' ' * (list_base_indent + 2) + stripped)
            elif not stripped:
                # Empty line
                result.append(line)
                in_list_block = False
            else:
                # Nested content - add 2 spaces
                result.append('  ' + line)
        else:
            result.append(line)

    return '\n'.join(result)


class FilterModule:
    """Ansible filter plugin."""

    def filters(self):
        return {
            'indent_yaml_lists': indent_yaml_lists,
        }
