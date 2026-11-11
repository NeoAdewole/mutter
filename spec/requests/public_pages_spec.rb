require 'rails_helper'

RSpec.describe 'Public pages and section landing pages', type: :request do
  describe 'section landing pages' do
    Section.all.each do |section|
      it "serves /#{section.key} to guests, with the section's title and blurb" do
        get "/#{section.key}"
        expect(response).to have_http_status(:success)
        expect(html.at_css('h1').text).to eq(section.title)
        expect(html.text).to include(section.blurb)
      end
    end

    it 'lists the published pages of that section, nested and in order, and nothing else' do
      guides = create(:page, :published, section: 'content', title: 'Guides', slug: 'guides')
      create(:page, :published, section: 'content', parent: guides, title: 'Beginner', slug: 'beginner')
      create(:page, :draft, section: 'content', parent: guides, title: 'Hidden child')
      create(:page, :draft, section: 'content', title: 'Hidden draft')
      create(:page, :published, section: 'gaming', title: 'Other section')

      get '/content'

      links = html.css('main a, [data-section-pages] a').map { |a| [a.text.strip, a['href']] }
      expect(links).to include(['Guides', '/content/guides'], ['Beginner', '/content/guides/beginner'])
      expect(response.body).not_to include('Hidden draft')
      expect(response.body).not_to include('Hidden child')
      # (the navbar legitimately lists every section's pages, so look at the landing list only)
      expect(html.at_css('[data-section-pages]').text).not_to include('Other section')
    end

    it 'says so when a section has no pages yet' do
      get '/community'
      expect(response.body).to match(/no pages/i)
    end

    it 'puts Live chat on the Streaming landing page' do
      get '/streaming'
      expect(html.css("[data-section-pages] a[href='/streaming/live-chat']")).not_to be_empty
    end

    it 'does not offer admin tools to guests' do
      get '/content'
      expect(response.body).not_to include('/admin')
    end

    it 'shows admins a shortcut to add a page in that section' do
      sign_in_as(create(:user, :admin))
      get '/content'
      expect(html.css("a[href='#{new_admin_page_path(section: 'content')}']")).not_to be_empty
    end

    it 'does not answer for things that are not sections' do
      get '/nonsense'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'a published page' do
    let!(:guides) { create(:page, :published, section: 'content', title: 'Guides', slug: 'guides', body: "# Welcome\n\nHello **world**") }
    let!(:beginner) do
      create(:page, :published, section: 'content', parent: guides, title: 'Beginner', slug: 'beginner', body: 'For starters')
    end

    it 'renders its title and Markdown body for guests' do
      get '/content/guides'

      expect(response).to have_http_status(:success)
      expect(html.at_css('article h1').text).to eq('Guides')
      expect(html.at_css('article').inner_html).to include('<h1>Welcome</h1>').and include('<strong>world</strong>')
    end

    it 'renders nested pages at their full path with breadcrumbs back up the tree' do
      get '/content/guides/beginner'

      expect(response).to have_http_status(:success)
      expect(html.at_css('article h1').text).to eq('Beginner')
      crumbs = html.css("nav[aria-label='Breadcrumb'] a").map { |a| [a.text.strip, a['href']] }
      expect(crumbs).to eq([['Content', '/content'], ['Guides', '/content/guides']])
      expect(html.at_css("nav[aria-label='Breadcrumb'] [aria-current='page']").text.strip).to eq('Beginner')
    end

    it 'lists its published sub pages' do
      create(:page, :draft, section: 'content', parent: guides, title: 'Secret child')

      get '/content/guides'

      expect(html.css("[data-sub-pages] a[href='/content/guides/beginner']")).not_to be_empty
      expect(response.body).not_to include('Secret child')
    end

    it 'is a 404 under the wrong section' do
      get '/gaming/guides'
      expect(response).to have_http_status(:not_found)
    end

    it 'is a 404 for an unknown page or an unknown sub page' do
      get '/content/nope'
      expect(response).to have_http_status(:not_found)
      get '/content/guides/nope'
      expect(response).to have_http_status(:not_found)
    end

    it 'shows no admin tools to guests or regular users' do
      get '/content/guides'
      expect(response.body).not_to include('/admin')

      sign_in_as(create(:user))
      get '/content/guides'
      expect(response.body).not_to include('/admin')
    end

    it 'shows admins an edit link' do
      sign_in_as(create(:user, :admin))
      get '/content/guides'
      expect(html.css("a[href='#{edit_admin_page_path(guides)}']")).not_to be_empty
    end
  end

  describe 'a draft page' do
    let!(:draft) { create(:page, :draft, section: 'content', title: 'Upcoming', slug: 'upcoming', body: 'Not yet') }

    it 'is a 404 for guests' do
      get '/content/upcoming'
      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include('Upcoming')
    end

    it 'is a 404 for regular users' do
      sign_in_as(create(:user))
      get '/content/upcoming'
      expect(response).to have_http_status(:not_found)
    end

    it 'is previewable by admins, clearly marked as a draft' do
      sign_in_as(create(:user, :admin))
      get '/content/upcoming'

      expect(response).to have_http_status(:success)
      expect(html.at_css('article h1').text).to eq('Upcoming')
      expect(html.at_css('[data-draft-notice]').text).to match(/draft/i)
    end

    it 'does not show the draft notice once published' do
      draft.update!(published: true)
      sign_in_as(create(:user, :admin))
      get '/content/upcoming'
      expect(html.at_css('[data-draft-notice]')).to be_nil
    end

    it 'is not leaked on the home page, the sitemap of any section, or the navbar' do
      get root_path
      get '/content'
      expect(response.body).not_to include('Upcoming')
    end
  end

  describe 'a published page under an unpublished parent' do
    let!(:parent) { create(:page, :draft, section: 'content', slug: 'parent') }
    let!(:child) { create(:page, :published, section: 'content', parent: parent, slug: 'child', title: 'Child') }

    it 'is not public' do
      get '/content/parent/child'
      expect(response).to have_http_status(:not_found)
    end

    it 'is previewable by an admin' do
      sign_in_as(create(:user, :admin))
      get '/content/parent/child'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'stored XSS' do
    let(:evil) do
      <<~MD
        <script>window.pwned = 1</script>
        <img src=x onerror="window.pwned = 2">
        [click](javascript:window.pwned=3)
        <iframe src="https://evil.example"></iframe>
      MD
    end

    it 'never reaches visitors, even if an admin account wrote it' do
      create(:page, :published, section: 'content', slug: 'evil', title: 'Evil <script>window.pwned = 4</script>', body: evil)

      get '/content/evil'

      expect(response).to have_http_status(:success)
      expect(response.body).not_to match(/<script[^>]*>\s*window\.pwned/i)
      expect(response.body).not_to include('onerror')
      # (markdown that points at a javascript: URL is left as inert text, never a link)
      expect(html.css('a').map { |a| a['href'].to_s }.grep(/javascript:/i)).to be_empty
      expect(html.css('[src]').map { |e| e['src'].to_s }.grep(/\A(javascript|data):/i)).to be_empty
      expect(response.body).not_to include('<iframe')
      expect(response.body).not_to include('<script>window.pwned = 4')
    end
  end

  describe 'Live chat (the old /streaming page)' do
    it 'now lives at /streaming/live-chat and still needs a login' do
      get '/streaming/live-chat'
      expect(response).to redirect_to(new_session_path)

      sign_in_as(create(:user))
      get '/streaming/live-chat'
      expect(response).to have_http_status(:success)
    end

    it 'is not shadowed by the page tree' do
      sign_in_as(create(:user))
      get live_chat_path
      expect(html.text).to include('Live chat from every channel')
    end
  end
end
