"""Unit tests for yaml_indent filter plugin."""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'filter_plugins'))

import pytest
from yaml_indent import indent_yaml_lists, get_indent, is_list_key, is_list_item


class TestHelperFunctions:
    """Tests for helper functions."""

    def test_get_indent_no_indent(self):
        assert get_indent("hello") == 0

    def test_get_indent_with_spaces(self):
        assert get_indent("  hello") == 2
        assert get_indent("    hello") == 4

    def test_get_indent_empty_line(self):
        assert get_indent("") == 0

    def test_is_list_key_simple(self):
        assert is_list_key("environment:") is True
        assert is_list_key("  volumes:") is True

    def test_is_list_key_double_colon(self):
        assert is_list_key("foo::") is False

    def test_is_list_key_not_key(self):
        assert is_list_key("- item") is False
        assert is_list_key("key: value") is False

    def test_is_list_item_simple(self):
        assert is_list_item("- item") is True
        assert is_list_item("  - indented") is True

    def test_is_list_item_not_list(self):
        assert is_list_item("key: value") is False
        assert is_list_item("plain text") is False


class TestIndentYamlLists:
    """Tests for the main indent_yaml_lists function."""

    def test_simple_list_indentation(self):
        input_yaml = """environment:
- FOO=bar
- BAZ=qux"""
        expected = """environment:
  - FOO=bar
  - BAZ=qux"""
        assert indent_yaml_lists(input_yaml) == expected

    def test_multiple_lists(self):
        input_yaml = """environment:
- FOO=bar
volumes:
- /data:/data"""
        expected = """environment:
  - FOO=bar
volumes:
  - /data:/data"""
        assert indent_yaml_lists(input_yaml) == expected

    def test_nested_dict_in_list(self):
        input_yaml = """configs:
- source: test
  target: /etc/test"""
        expected = """configs:
  - source: test
    target: /etc/test"""
        assert indent_yaml_lists(input_yaml) == expected

    def test_empty_input(self):
        assert indent_yaml_lists("") == ""

    def test_no_lists(self):
        input_yaml = """services:
  web:
    image: nginx"""
        assert indent_yaml_lists(input_yaml) == input_yaml

    def test_already_indented_list(self):
        input_yaml = """services:
  web:
    environment:
    - FOO=bar"""
        expected = """services:
  web:
    environment:
      - FOO=bar"""
        assert indent_yaml_lists(input_yaml) == expected

    def test_deeply_nested(self):
        input_yaml = """services:
  web:
    configs:
    - source: app-config
      target: /etc/app/config.json"""
        expected = """services:
  web:
    configs:
      - source: app-config
        target: /etc/app/config.json"""
        assert indent_yaml_lists(input_yaml) == expected

    def test_unicode_content(self):
        input_yaml = """labels:
- "description=日本語テスト"
- "emoji=🚀"
- "accent=café"""
        expected = """labels:
  - "description=日本語テスト"
  - "emoji=🚀"
  - "accent=café"""
        assert indent_yaml_lists(input_yaml) == expected

    def test_empty_lines_between_sections(self):
        input_yaml = """environment:
- FOO=bar

volumes:
- /data:/data"""
        expected = """environment:
  - FOO=bar

volumes:
  - /data:/data"""
        assert indent_yaml_lists(input_yaml) == expected

    def test_key_with_value_not_list(self):
        input_yaml = """image: nginx:latest
container_name: web
environment:
- FOO=bar"""
        expected = """image: nginx:latest
container_name: web
environment:
  - FOO=bar"""
        assert indent_yaml_lists(input_yaml) == expected

    def test_preserves_double_colon(self):
        input_yaml = """weird::
- item"""
        # Double colon should not trigger list indent
        assert indent_yaml_lists(input_yaml) == input_yaml


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
