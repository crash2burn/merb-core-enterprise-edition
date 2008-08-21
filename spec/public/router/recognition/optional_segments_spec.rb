require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe "Recognizing requests for the routes with" do
  
  describe "a route with optional segments", :shared => true do
    
    it "should match when the required segment matches" do
      route_to("/hello").should have_route(:first => 'hello', :second => nil, :third => nil)
    end
    
    it "should match when the required and optional segment(s) match" do
      route_to("/hello/world/sweet").should have_route(:first => "hello", :second => "world", :third => "sweet")
    end
    
  end
  
  describe "a single optional segment" do
    before(:each) do
      Merb::Router.prepare do |r|
        r.match!("/:first(/:second/:third)")
      end
    end
    
    it_should_behave_like "a route with optional segments"
    
    it "should not match the route if the optional segment is only partially present" do
      route_to("/hello/world").should have_nil_route
    end
    
    it "should not match the optional segment if the optional segment is present but doesn't match a named segment condition" do
      Merb::Router.prepare do |r|
        r.match!("/:first(/:second)", :second => /^\d+$/)
      end
      
      route_to("/hello/world").should have_nil_route
    end
    
    it "should not match if the optional segment is present but not the required segment" do
      Merb::Router.prepare do |r|
        r.match!("/:first(/:second)", :first => /^[a-z]+$/, :second => /^\d+$/)
      end
      
      route_to("/123").should have_nil_route
    end
  end
  
  describe "multiple optional segments" do
    before(:each) do
      Merb::Router.prepare do |r|
        r.match!("/:first(/:second)(/:third)")
      end
    end
    
    it_should_behave_like "a route with optional segments"
    
    it "should match when one optional segment matches" do
      route_to("/hello/sweet").should have_route(:first => "hello", :second => "sweet")
    end
    
    it "should be able to distinguish the optional segments when there are conditions on them" do
      Merb::Router.prepare do |r|
        r.match!("/:first(/:second)(/:third)", :second => /^\d+$/)
      end
      
      route_to("/hello/world").should have_route(:first => "hello", :second => nil, :third => "world")
      route_to("/hello/123").should have_route(:first => "hello", :second => "123", :third => nil)
    end
    
    it "should not match any of the optional segments if the segments can't be matched" do
      Merb::Router.prepare do |r|
        r.match!("(/:first/abc)(/:bar)")
      end
      
      route_to("/abc/hello").should have_nil_route
      route_to("/hello/world/abc").should have_nil_route
    end
  end
  
  describe "nested optional segments" do
    before(:each) do
      Merb::Router.prepare do |r|
        r.match!("/:first(/:second(/:third))")
      end
    end
    
    it_should_behave_like "a route with optional segments"
    
    it "should match when the first optional segment matches" do
      route_to("/hello/world").should have_route(:first => "hello", :second => "world")
    end
    
    it "should not match the nested optional group unless the containing optional group matches" do
      Merb::Router.prepare do |r|
        r.match!("/:first(/:second(/:third))", :second => /^\d+$/)
      end
      
      route_to("/hello/world").should have_nil_route
    end
  end
  
  describe "nested match blocks with optional segments" do
    it "should allow wrapping of nested routes all having a shared optional segment" do
      Merb::Router.prepare do |r|
        r.match("(/:language)") do |l|
          l.match("/guides/:action/:id").to(:controller => "tour_guides")
        end
      end

      route_to('/guides/search/london').should have_route(:controller => 'tour_guides', :action => "search", :id => "london")
    end
  end
  
end