# Turns admin-authored Markdown into HTML that is safe to put on a public page.
#
# The body is trusted only as far as the admin account is: if that account were
# compromised, nothing written here should be able to run script in a visitor's
# browser. So there are three independent layers:
#   1. Redcarpet drops any raw HTML (filter_html) and non-web link schemes.
#   2. A pass that forces safe link attributes and removes non-http(s) images.
#   3. An allow-list sanitizer (Rails/Loofah) as the final word, which is the
#      only thing whose output is marked html_safe.
class MarkdownRenderer
  ALLOWED_TAGS = %w[
    h1 h2 h3 h4 h5 h6 p br hr strong em del b i ul ol li blockquote pre code
    a img table thead tbody tr th td
  ].freeze
  ALLOWED_ATTRIBUTES = %w[href title rel src alt].freeze
  LINK_REL = 'noopener noreferrer nofollow'.freeze
  WEB_URL = %r{\Ahttps?://}i

  MARKDOWN = Redcarpet::Markdown.new(
    Redcarpet::Render::HTML.new(filter_html: true, safe_links_only: true, no_styles: true),
    autolink: true, tables: true, fenced_code_blocks: true, strikethrough: true,
    no_intra_emphasis: true, lax_spacing: true
  )

  def self.call(markdown)
    new.call(markdown)
  end

  def call(markdown)
    return ''.html_safe if markdown.to_s.strip.empty?

    html = MARKDOWN.render(markdown.to_s)
    ActionController::Base.helpers.sanitize(tidy(html), tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
  end

  private

  def tidy(html)
    fragment = Nokogiri::HTML5.fragment(html)
    fragment.css('a').each { |link| link['rel'] = LINK_REL }
    fragment.css('img').each { |image| image.remove unless image['src'].to_s.strip.match?(WEB_URL) }
    fragment.to_html
  end
end
