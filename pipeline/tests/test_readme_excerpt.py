import unittest
from pipeline.collect import README_EXCERPT_LIMIT, readme_excerpt


class ReadmeExcerptTests(unittest.TestCase):
    def test_skips_logo_badges_heading_and_language_bar(self):
        md = """<p align="center"><img src="logo.svg" width="120"></p>

# Tool

[![CI](https://x/badge.svg)](https://x) [![npm](https://x/npm.svg)](https://x)

[English](README.md) · [中文](README.zh.md) · [日本語](README.ja.md) · [한국어](README.ko.md)

Tool is a **fast** command-line app that turns [Markdown](https://commonmark.org) notes into a searchable site. It runs `offline`.

## Install
"""
        self.assertEqual(readme_excerpt(md), "Tool is a fast command-line app that turns Markdown notes into a searchable site. It runs offline.")

    def test_html_link_bar_caption_quote_and_url_are_noise(self):
        md = """<p align="center">
  <a href="a.md">Català</a>
  <a href="b.md">Español</a>
  <a href="c.md">Français</a>
</p>

<p align="center"><sub><em>The mascot of the project, drawn by a friend</em></sub></p>

> [!NOTE]
> We moved to a new organization last month, please update your remotes.

https://github.com/user-attachments/assets/0000

Viewer renders large photo libraries on your own server, with face search and shared albums for families.
"""
        self.assertEqual(readme_excerpt(md), "Viewer renders large photo libraries on your own server, with face search and shared albums for families.")

    def test_skips_code_tables_lists_and_stops_at_a_list(self):
        md = """```sh
pip install thing --with a very long command line that is not a description at all
```

| Feature | Status |
| --- | --- |

- first bullet that is long enough to look like a sentence, but is a list item
- second bullet

Thing schedules background jobs for Python services and retries them safely. It supports:
1. Cron expressions
2. Rate limits
"""
        self.assertEqual(readme_excerpt(md), "Thing schedules background jobs for Python services and retries them safely. It supports.")

    def test_short_lead_joins_the_next_paragraph(self):
        md = "Tiny engine for immense models on ordinary laptops.\n\nIt runs very large open models on the laptop you already own by streaming weights from disk.\n\nThird paragraph is not included."
        self.assertEqual(readme_excerpt(md), "Tiny engine for immense models on ordinary laptops. It runs very large open models on the laptop you already own by streaming weights from disk.")

    def test_repeating_the_description_is_skipped(self):
        md = "A fast terminal emulator.\n\nIt renders with the GPU and uses native platform UI on macOS and Linux."
        self.assertEqual(readme_excerpt(md, "A fast terminal emulator."), "It renders with the GPU and uses native platform UI on macOS and Linux.")

    def test_chinese_paragraph_and_nothing_readable(self):
        self.assertEqual(readme_excerpt("# 标题\n\n基于 Playwright 和 AI 的多任务实时监控，提供完整的网页管理界面。"), "基于 Playwright 和 AI 的多任务实时监控，提供完整的网页管理界面。")
        self.assertIsNone(readme_excerpt("# Title\n\n![demo](demo.gif)\n\n```\ncode\n```\n"))
        self.assertIsNone(readme_excerpt(""))

    def test_long_text_is_cut_at_a_sentence(self):
        sentence = "This library parses configuration files and validates them against a schema. "
        text = readme_excerpt(sentence * 10)
        self.assertLessEqual(len(text), README_EXCERPT_LIMIT)
        self.assertTrue(text.endswith("schema."))


if __name__ == "__main__":
    unittest.main()
