# RST Conventions for Fess Articles

## Title

```rst
============================================================
タイトル
============================================================
```

Use `=` overline and underline. The `=` line should be at least as long as the title.

## Section Hierarchy

```
= (overline + underline) : Document title (once per file)
= (underline only)       : Major sections
- (underline)             : Subsections
^ (underline)             : Sub-subsections
~ (underline)             : Paragraph-level
```

## Code Blocks

Syntax-highlighted:

```rst
.. code-block:: java

    public class Example {
    }
```

Shell commands (plain literal block):

```rst
::

    $ docker compose up -d
    $ curl http://localhost:8080/api/v1/health
```

Supported languages: java, python, javascript, bash, yaml, json, xml, html, css, sql, rst

## Tables

```rst
.. list-table:: テーブルタイトル
   :header-rows: 1
   :widths: 25 35 40

   * - ヘッダー1
     - ヘッダー2
     - ヘッダー3
   * - セル1
     - セル2
     - セル3
```

Always include `:header-rows: 1` and `:widths:`.

## Images

Reference in text with substitution:

```rst
管理ページへのログイン
|image1|

.. |image1| image:: ../../resources/images/ja/article/{name}/filename.png
```

Image definitions go at the bottom of the file.

## Links

External:
```rst
`リンクテキスト <https://example.com/>`__
```

Internal doc reference:
```rst
:doc:`articles/guide-01`
```

## Notes

```rst
.. note::

   注意事項の内容
```

## Bullet Lists

```rst
- 項目1
- 項目2

  - ネスト項目

- 項目3
```

Use `-` for unordered, `1.` for ordered. Blank line before and after the list.

## Inline Markup

- Bold: `**太字**`
- Inline code: ` ``コード`` `
- Product names: Fess, OpenSearch, Docker, LastaFlute (proper case, no backticks)
- Config properties, CLI commands, paths: use inline code
