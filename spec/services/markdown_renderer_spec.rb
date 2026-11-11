require 'rails_helper'

RSpec.describe MarkdownRenderer do
  def render(markdown)
    described_class.call(markdown)
  end

  def html(markdown)
    Nokogiri::HTML.fragment(render(markdown))
  end

  describe 'formatting' do
    it 'renders headings, emphasis, lists, links and code' do
      out = html("# Title\n\nSome *em* and **strong**.\n\n- one\n- two\n\n[site](https://example.com)\n\n`code`")
      expect(out.at_css('h1').text).to eq('Title')
      expect(out.at_css('em').text).to eq('em')
      expect(out.at_css('strong').text).to eq('strong')
      expect(out.css('li').map(&:text)).to eq(%w[one two])
      expect(out.at_css('a')['href']).to eq('https://example.com')
      expect(out.at_css('code').text).to eq('code')
    end

    it 'renders tables and fenced code blocks' do
      out = html("| a | b |\n|---|---|\n| 1 | 2 |\n\n```\nputs 1\n```")
      expect(out.at_css('table td').text).to eq('1')
      expect(out.at_css('pre code').text).to include('puts 1')
    end

    it 'is html_safe so views can output it directly' do
      expect(render('hi')).to be_html_safe
    end

    it 'returns an empty string for nil or blank input' do
      expect(render(nil)).to eq('')
      expect(render('   ')).to eq('')
    end

    it 'makes links safe to follow' do
      out = html('[x](https://example.com)')
      expect(out.at_css('a')['rel']).to eq('noopener noreferrer nofollow')
    end

    it 'keeps images with http(s) sources' do
      out = html('![alt text](https://example.com/a.png)')
      expect(out.at_css('img')['src']).to eq('https://example.com/a.png')
      expect(out.at_css('img')['alt']).to eq('alt text')
    end
  end

  describe 'sanitization (the body is admin-authored but rendered publicly)' do
    {
      'script tags' => '<script>alert(1)</script>',
      'inline event handlers on img' => '<img src="x" onerror="alert(1)">',
      'inline event handlers on a' => '<a href="https://example.com" onclick="alert(1)">x</a>',
      'iframes' => '<iframe src="https://evil.example"></iframe>',
      'objects and embeds' => '<object data="x"></object><embed src="x">',
      'style tags' => '<style>body{display:none}</style>',
      'forms' => '<form action="https://evil.example"><input name="x"></form>',
      'svg with script' => '<svg><script>alert(1)</script></svg>',
      'svg onload' => '<svg onload="alert(1)"></svg>',
      'meta refresh' => '<meta http-equiv="refresh" content="0;url=https://evil.example">',
      'base tag' => '<base href="https://evil.example/">',
      'noscript breakout' => '<noscript><p title="</noscript><img src=x onerror=alert(1)>"></noscript>'
    }.each do |name, payload|
      it "strips #{name}" do
        out = render("before\n\n#{payload}\n\nafter")
        expect(out).not_to match(/<script|<iframe|<object|<embed|<style|<form|<svg|<meta|<base|<input|<noscript/i)
        expect(out).not_to match(/\son\w+\s*=/i)
        expect(out).to include('before').and include('after')
      end
    end

    [
      '[x](javascript:alert(1))',
      '[x](JaVaScRiPt:alert(1))',
      '[x](&#106;avascript:alert(1))',
      '[x](java&#x09;script:alert(1))',
      '[x](vbscript:msgbox(1))',
      '[x](data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==)',
      '<a href="javascript:alert(1)">x</a>',
      '<a href="  javascript:alert(1)">x</a>',
      '<a href="jav&#x61;script:alert(1)">x</a>',
      "[ref][1]\n\n[1]: javascript:alert(1)"
    ].each do |payload|
      it "does not leave a dangerous link target for #{payload.inspect}" do
        links = html(payload).css('a').map { |a| a['href'].to_s.strip.downcase }
        expect(links.grep(/\A(javascript|vbscript|data):/)).to be_empty
        expect(render(payload).downcase).not_to match(/href="\s*(javascript|vbscript|data):/)
      end
    end

    it 'drops images whose source is not http(s)' do
      ['![x](javascript:alert(1))', '![x](data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=)', '<img src="javascript:alert(1)">'].each do |payload|
        expect(html(payload).css('img').map { |i| i['src'].to_s }.grep(/\A(javascript|data):/i)).to be_empty
      end
    end

    it 'does not allow style, class or id attributes through' do
      out = render('<p style="position:fixed" class="x" id="y">hi</p>')
      expect(out).not_to match(/style=|class=|id=/)
    end

    it 'does not execute angle brackets typed as text' do
      expect(render('1 < 2 and `<script>`')).not_to include('<script>')
    end
  end
end
