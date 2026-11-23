require 'rails_helper'

RSpec.describe 'Pages built from blocks', type: :request do
  let(:about) { SitePages.page('about') }

  def blocks
    html.css('[data-block]')
  end

  describe 'the Home page, unedited' do
    before { get root_path }

    it 'looks like it did before it could be edited' do
      expect(response).to have_http_status(:success)
      expect(blocks.map { |block| block['data-block'] }).to eq(%w[carousel cards text])
      expect(html.css('[data-carousel-target="slide"]').size).to eq(4)
      expect(html.css('h1')).to be_empty
      expect(html.css('[data-card]').size).to eq(4)
      expect(html.at_css('[data-block="text"]').text).to include('We are building a digital community')
      expect(html.css('[data-block="text"] li').map { |li| li.text.strip }).to eq(
        ['Empowers creators', 'Fosters collaboration', 'Encourages innovation', 'Builds lasting connections']
      )
    end

    it 'has a card for each section: its picture, name, text and button' do
      Section.all.each_with_index do |section, index|
        card = html.css('[data-card]')[index]
        expect(card.at_css('h3').text).to eq(section.title)
        expect(card.at_css('.cms-body').text).to eq(section.blurb)
        expect(card.at_css('img')['src']).to start_with('https://picsum.photos/id/')
        expect(card.at_css('img')['alt']).to be_present
        expect(card.at_css('a.btn')['href']).to eq(section.path)
        expect(card.at_css('a.btn').text).to eq("Explore #{section.title}")
      end
    end

    it 'has four columns on a wide screen, fewer on narrow ones' do
      classes = html.at_css('[data-block="cards"] > div')['class'].split

      expect(classes).to include('grid-cols-1', 'tablet:grid-cols-2', 'laptop:grid-cols-4')
    end

    it 'shows no Edit button to a visitor' do
      expect(response.body).not_to include('Edit this page')
    end
  end

  describe 'columns' do
    it 'turns the chosen count into a grid with fewer columns on narrower screens' do
      expected = {
        1 => %w[grid-cols-1],
        2 => %w[grid-cols-1 tablet:grid-cols-2],
        3 => %w[grid-cols-1 tablet:grid-cols-2 laptop:grid-cols-3],
        4 => %w[grid-cols-1 tablet:grid-cols-2 laptop:grid-cols-4],
        5 => %w[grid-cols-1 tablet:grid-cols-2 laptop:grid-cols-3 desktop:grid-cols-5],
        6 => %w[grid-cols-1 tablet:grid-cols-2 laptop:grid-cols-3 desktop:grid-cols-6]
      }
      about.blocks.destroy_all
      expected.each_key do |columns|
        row = create(:page_block, :cards, page: about, columns: columns)
        create(:block_item, block: row, title: "Card for #{columns}")
      end

      get about_path

      grids = html.css('[data-block="cards"]')
      expect(grids.map { |grid| grid['data-columns'].to_i }).to eq(expected.keys)
      expect(grids.map { |grid| grid.at_css('div.grid')['class'].split & expected.values.flatten.uniq }).to eq(expected.values)
    end
  end

  describe 'blocks on About' do
    before { about.blocks.destroy_all }

    it 'show in the order they were put in, beneath the main text' do
      create(:page_block, :text, page: about, heading: 'Second', body: 'two')
      create(:page_block, :text, page: about, heading: 'Third', body: 'three')
      first = create(:page_block, :text, page: about, heading: 'First', body: 'one')
      first.move(:up)
      first.move(:up)

      get about_path

      expect(html.css('[data-block="text"] h2').map(&:text)).to eq(%w[First Second Third])
      expect(html.at_css('h1').text).to eq('About Us')
      expect(response.body.index('The Idea')).to be < response.body.index('First')
    end

    it 'hides the title when the page asks for that' do
      about.update!(show_title: false)
      get about_path
      expect(html.css('h1')).to be_empty
    end

    it 'renders text blocks as safe Markdown and escapes headings' do
      create(:page_block, :text, page: about, heading: '<script>alert(1)</script>', body: "**bold** <img src=x onerror=alert(1)>\n\n[go](javascript:alert(1))")

      get about_path

      block = html.at_css('[data-block="text"]')
      expect(block.at_css('h2').text).to eq('<script>alert(1)</script>')
      expect(block.at_css('strong').text).to eq('bold')
      expect(response.body).not_to include('onerror')
      expect(response.body).to include('&lt;script&gt;')
      expect(block.css('a[href^="javascript"]')).to be_empty
    end

    it 'shows nothing for an empty text block, or a row with no cards' do
      create(:page_block, :text, page: about, body: '')
      create(:page_block, :cards, page: about)
      create(:page_block, :carousel, page: about)

      get about_path

      expect(blocks).to be_empty
    end
  end

  describe 'carousel blocks' do
    let(:carousel) { create(:page_block, :carousel, page: about) }

    before { about.blocks.destroy_all }

    it 'show their slides, and a slide can link somewhere' do
      create(:block_item, :slide, block: carousel, image_url: 'https://images.example.com/a.jpg', alt_text: 'Lake', link_url: '/content/lakes')
      create(:block_item, :slide, block: carousel, image_url: 'https://images.example.com/b.jpg', alt_text: 'Hills')

      get about_path

      slides = html.css('[data-carousel-target="slide"]')
      expect(slides.map { |slide| slide.at_css('img')['alt'] }).to eq(%w[Lake Hills])
      expect(slides.first.at_css('a')['href']).to eq('/content/lakes')
      expect(slides.last.at_css('a')).to be_nil
      expect(html.css('[data-carousel-target="indicator"]').size).to eq(2)
    end

    it 'can sit on a page of a section as well' do
      page = create(:page, :published, section: 'content', slug: 'lakes')
      create(:block_item, :slide, block: create(:page_block, :carousel, page: page))

      get '/content/lakes'

      expect(html.css('[data-block="carousel"] [data-carousel-target="slide"]').size).to eq(1)
    end

    it 'leave live streams out unless the block asks for them, and never ask Twitch' do
      create(:block_item, :slide, block: carousel)
      allow(Twitch::LiveStreams).to receive(:current)

      get about_path

      expect(Twitch::LiveStreams).not_to have_received(:current)
      expect(html.css('iframe')).to be_empty
    end

    it 'put live streams first when asked, asking Twitch once however many carousels there are' do
      live = [Twitch::Stream.new(login: 'alice', name: 'Alice', title: 'Speedrun', game: 'Celeste', viewers: 10)]
      allow(Twitch::LiveStreams).to receive(:current).and_return(live)
      carousel.update!(show_live_streams: true)
      create(:block_item, :slide, block: carousel)
      second = create(:page_block, :carousel, page: about, show_live_streams: true)
      create(:block_item, :slide, block: second)

      get about_path

      expect(Twitch::LiveStreams).to have_received(:current).once.with(limit: 5)
      expect(html.css('[data-block="carousel"]').map { |block| block.css('[data-carousel-target="slide"]').size }).to eq([2, 2])
      expect(html.css('iframe').size).to eq(2)
    end

    it 'follow the admin settings for streams: off, and how many' do
      carousel.update!(show_live_streams: true)
      create(:block_item, :slide, block: carousel)
      allow(Twitch::LiveStreams).to receive(:current).and_return([])

      SiteSetting.update_values('homepage_streams_limit' => '2')
      get about_path
      expect(Twitch::LiveStreams).to have_received(:current).with(limit: 2)

      SiteSetting.update_values('homepage_streams_enabled' => '0')
      get about_path
      expect(Twitch::LiveStreams).to have_received(:current).once
    end

    it 'show a carousel of live streams alone when it has no slides' do
      live = [Twitch::Stream.new(login: 'alice', name: 'Alice', title: 'Speedrun', game: 'Celeste', viewers: 10)]
      allow(Twitch::LiveStreams).to receive(:current).and_return(live)
      carousel.update!(show_live_streams: true)

      get about_path

      expect(html.css('[data-carousel-target="slide"]').size).to eq(1)
    end
  end

  describe 'cards that feature a page' do
    let(:row) { create(:page_block, :cards, page: about, columns: 2) }
    let(:featured) do
      create(:page, :published, section: 'content', title: 'Beginner guide', slug: 'beginner', body: "## Welcome\n\nStart your **journey** here.")
    end

    before { about.blocks.destroy_all }

    it 'show the page title, the start of its text and a button to it' do
      create(:block_item, block: row, title: '', featured_page: featured)

      get about_path

      card = html.at_css('[data-card]')
      expect(card.at_css('h3').text).to eq('Beginner guide')
      expect(card.at_css('.cms-body').text).to eq('Welcome Start your journey here.')
      expect(card.at_css('a.btn')['href']).to eq('/content/beginner')
      expect(card.at_css('a.btn').text).to eq('Read more')
      expect(card['data-hidden-from-visitors']).to be_nil
    end

    it 'use the card own words and picture where it has them' do
      create(:block_item, block: row, title: 'Start here', body: 'Plain *words*', featured_page: featured, link_label: 'Begin',
                          image_url: 'https://images.example.com/a.png', alt_text: 'A path')

      get about_path

      card = html.at_css('[data-card]')
      expect(card.at_css('h3').text).to eq('Start here')
      expect(card.at_css('.cms-body').text.strip).to eq('Plain words')
      expect(card.at_css('a.btn').text).to eq('Begin')
      expect(card.at_css('a.btn')['href']).to eq('/content/beginner')
      expect(card.at_css('img')['alt']).to eq('A path')
    end

    it 'follow the page when it is renamed or its text changes' do
      create(:block_item, block: row, title: '', featured_page: featured)
      featured.update!(title: 'Renamed guide', body: 'Fresh words')

      get about_path

      card = html.at_css('[data-card]')
      expect([card.at_css('h3').text, card.at_css('.cms-body').text]).to eq(['Renamed guide', 'Fresh words'])
    end

    it 'follow the page when its address changes' do
      create(:block_item, block: row, featured_page: featured)
      featured.update!(slug: 'new-address')

      get about_path

      expect(html.at_css('[data-card] a.btn')['href']).to eq('/content/new-address')
    end

    it 'can link elsewhere instead, opening other sites safely' do
      create(:block_item, block: row, title: 'Out there', link_url: 'https://example.com/x')
      create(:block_item, block: row, title: 'In here', link_url: '/gaming')

      get about_path

      links = html.css('[data-card] a.btn')
      expect(links.map { |a| a['href'] }).to eq(['https://example.com/x', '/gaming'])
      expect(links.first['rel']).to eq('noopener noreferrer')
      expect(links.last['rel']).to be_nil
    end

    it 'show no button when there is nowhere to go' do
      create(:block_item, block: row, title: 'Just a note')

      get about_path

      expect(html.at_css('[data-card] a')).to be_nil
    end

    it 'is escaped: titles, alt text, and the featured page text' do
      featured.update!(title: '<b>Bold</b>', body: '<script>alert(1)</script> Hi & bye')
      create(:block_item, block: row, title: '', featured_page: featured, image_url: 'https://images.example.com/a.png', alt_text: '"><script>x</script>')

      get about_path

      expect(response.body).not_to include('<script>alert(1)</script>')
      expect(response.body).not_to include('<script>x</script>')
      card = html.at_css('[data-card]')
      expect(card.at_css('h3').text).to eq('<b>Bold</b>')
      expect(card.at_css('.cms-body').text).to include('Hi & bye')
      expect(card.at_css('img')['alt']).to eq('"><script>x</script>')
    end

    describe 'when the featured page is a draft' do
      before do
        featured.update!(published: false)
        create(:block_item, block: row, title: '', featured_page: featured)
        create(:block_item, block: row, title: 'Plain card')
      end

      it 'is left out for visitors, leaving the other cards' do
        get about_path

        expect(html.css('[data-card] h3').map(&:text)).to eq(['Plain card'])
        expect(response.body).not_to include('Beginner guide')
      end

      it 'is left out for signed-in members who are not admins' do
        sign_in_as(create(:user))
        get about_path
        expect(html.css('[data-card] h3').map(&:text)).to eq(['Plain card'])
      end

      it 'is shown to admins, marked so they know visitors cannot see it' do
        sign_in_as(create(:user, :admin))

        get about_path

        cards = html.css('[data-card]')
        expect(cards.map { |card| card.at_css('h3').text }).to eq(['Beginner guide', 'Plain card'])
        expect(cards.first['data-hidden-from-visitors']).not_to be_nil
        expect(cards.first.text).to include('Hidden from visitors')
        expect(cards.last['data-hidden-from-visitors']).to be_nil
      end

      it 'appears for everyone once the page is published' do
        featured.update!(published: true)
        get about_path
        expect(html.css('[data-card] h3').map(&:text)).to eq(['Beginner guide', 'Plain card'])
      end
    end

    it 'keeps showing a card that has its own words after the featured page is deleted, and drops one that has not' do
      create(:block_item, block: row, title: 'Mine', featured_page: featured)
      create(:block_item, block: row, title: '', featured_page: featured)

      featured.destroy!
      get about_path

      expect(html.css('[data-card] h3').map(&:text)).to eq(['Mine'])
      expect(html.at_css('[data-card] a')).to be_nil
    end
  end

  describe 'a section landing page' do
    it 'shows its own text and blocks above the list of the section pages' do
      create(:page, :published, section: 'gaming', title: 'Reviews', slug: 'reviews')
      create(:page_block, :text, page: SitePages.page('gaming'), heading: 'Featured this week', body: 'Come and see')

      get '/gaming'

      expect(html.at_css('h1').text).to eq('Gaming')
      expect(html.at_css('[data-block="text"] h2').text).to eq('Featured this week')
      expect(response.body.index('Featured this week')).to be < response.body.index('data-section-pages')
      expect(html.css('[data-section-pages] a').map { |a| a['href'] }).to include('/gaming/reviews')
    end

    it 'shows what an admin wrote instead of the original blurb' do
      SitePages.page('gaming').update!(body: 'A fresh welcome to Gaming.')

      get '/gaming'

      expect(html.text).to include('A fresh welcome to Gaming.')
      expect(html.text).not_to include(Section.find('gaming').blurb)
    end

    it 'gives an admin the Edit button and the Add a page button' do
      sign_in_as(create(:user, :admin))

      get '/community'

      expect(html.at_css("a[href='#{edit_admin_page_path(SitePages.page('community'))}']").text).to eq('Edit this page')
      expect(html.at_css("a[href='#{new_admin_page_path(section: 'community')}']")).to be_present
    end
  end

  describe 'an ordinary page' do
    it 'shows the main text then its blocks, and keeps its breadcrumb and sub page list' do
      guides = create(:page, :published, section: 'content', title: 'Guides', slug: 'guides', body: 'Intro text')
      create(:page, :published, section: 'content', parent: guides, title: 'Beginner')
      create(:page_block, :text, page: guides, body: 'Block text')

      get '/content/guides'

      expect(html.at_css('h1').text).to eq('Guides')
      expect(html.css('[data-block="text"]').text).to include('Block text')
      expect(response.body.index('Intro text')).to be < response.body.index('Block text')
      expect(html.at_css('nav[aria-label="Breadcrumb"]')).to be_present
      expect(html.css('[data-sub-pages] a').map(&:text)).to eq(['Beginner'])
    end

    it 'can hide its title' do
      create(:page, :published, section: 'content', slug: 'quiet', show_title: false)

      get '/content/quiet'

      expect(html.css('h1')).to be_empty
    end

    it 'shows an admin the blocks of a draft they are previewing' do
      draft = create(:page, :draft, section: 'content', slug: 'draft')
      create(:page_block, :text, page: draft, body: 'Preview me')
      sign_in_as(create(:user, :admin))

      get '/content/draft'

      expect(html.at_css('[data-draft-notice]')).to be_present
      expect(html.at_css('[data-block="text"]').text).to include('Preview me')
    end

    it 'does not leak the blocks of a draft to visitors' do
      draft = create(:page, :draft, section: 'content', slug: 'draft')
      create(:page_block, :text, page: draft, body: 'Secret block')

      get '/content/draft'

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include('Secret block')
    end
  end

  describe 'maintenance mode' do
    it 'still covers Home' do
      SiteSetting.update_values('maintenance_mode' => '1')
      get root_path
      expect(response).to have_http_status(:service_unavailable)
    end
  end
end
