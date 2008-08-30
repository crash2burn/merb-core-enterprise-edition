require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe "When recognizing requests," do
  
  describe "a router with many routes" do
    
    it "should be awesome"
    
  end
  
end

describe "Old specs" do
  before(:each) do
    pending "These are old specs"
  end
  
  it "should inherit the parameters through many levels" do
    Merb::Router.prepare do
      match('/alpha').to(:controller=>'Alphas') do |alpha|
        alpha.match('/beta').to(:action=>'normal') do |beta|
          beta.match('/:id').to(:id=>':id')
        end
      end
    end
    route_to('/alpha/beta/gamma').should have_route(:controller=>'Alphas',:action=>'normal', :id=>'gamma')
  end
  
  it "allows wrapping of nested routes all having shared argument" do
    Merb::Router.prepare do
      match('/:language') do |i18n|
        i18n.match('/:controller/:action').to
      end
    end
    route_to('/fr/hotels/search').should have_route(:controller => 'hotels', :action => "search", :language => "fr")
  end
  
  it "allows wrapping of nested routes all having shared argument" do
    Merb::Router.prepare do
      match(/\/?(.*)?/).to(:language => "[1]") do |l|
        l.match("/guides/:action/:id").to(:controller => "tour_guides")
      end
    end

    route_to('/en/guides/search/london').should have_route(:controller => 'tour_guides', :action => "search", :language => "en", :id => "london")
  end
end