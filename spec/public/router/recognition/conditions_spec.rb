require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe "When recognizing requests," do
  
  describe "a route with a String path condition" do
    
    before(:each) do
      Merb::Router.prepare do |r|
        r.match("/info").to(:controller => "info", :action => "foo")
      end
    end
    
    it "should match the path and return the parameters passed to #to" do
      route_to("/info").should have_route(:controller => "info", :action => "foo", :id => nil)
    end
    
    it "should not match a different path" do
      route_to("/notinfo").should have_nil_route
    end
  end
  
  describe "a route with a Request method condition" do
    
    before(:each) do
      Merb::Router.prepare do |r|
        r.match(:method => :post).to(:controller => "all", :action => "posting")
      end
    end
    
    it "should match any path with a post method" do
      route_to("/foo/create/12", :method => "post").should have_route(:controller => "all", :action => "posting")
      route_to("", :method => "post").should have_route(:controller => "all", :action => "posting")
    end
    
    it "should not match any paths that don't have a post method" do
      route_to("/foo/create/12", :method => "get").should have_nil_route
      route_to("", :method => "get").should have_nil_route
    end
    
  end
  
  describe "a route with Request protocol condition and a path condition" do
    
    before(:each) do
      Merb::Router.prepare do |r|
        r.match("/foo", :protocol => "http://").to(:controller => "plain", :action => "text")
      end
    end
    
    it "should match the route if the path and the protocol match" do
      route_to("/foo", :protocol => "http://").should have_route(:controller => "plain", :action => "text")
    end
    
    it "should not match if the route does not match" do
      route_to("/bar", :protocol => "http://").should have_nil_route
    end
    
    it "should not match if the protocol does not match" do
      route_to("/foo", :protocol => "https://").should have_nil_route
    end
  end
  
  describe "a route containing path variable conditions" do
    
    it "should match only if the condition is satisfied" do
      Merb::Router.prepare { |r| r.match!("/foo/:bar", :bar => /\d+/) }
      
      route_to("/foo/123").should have_route(:bar => "123")
      route_to("/foo/abc").should have_nil_route
    end
    
    it "should be able to handle conditions with anchors" do
      Merb::Router.prepare do |r|
        r.match("/foo/:bar") do |bar|
          bar.match(:bar => /^\d+$/).to(:controller => "both")
          bar.match(:bar => /^\d+/ ).to(:controller => "start")
          bar.match(:bar => /\d+$/ ).to(:controller => "end")
          bar.match(:bar => /\d+/  ).to(:controller => "none")
        end
      end
      
      route_to("/foo/123456").should have_route(:controller => "both",  :bar => "123456")
      route_to("/foo/123abc").should have_route(:controller => "start", :bar => "123abc")
      route_to("/foo/abc123").should have_route(:controller => "end",   :bar => "abc123")
      route_to("/foo/ab123c").should have_route(:controller => "none",  :bar => "ab123c")
      route_to("/foo/abcdef").should have_nil_route
    end
    
    it "should match only if all conditions are satisied" do
      Merb::Router.prepare do |r|
        r.match!("/:foo/:bar", :foo => /abc/, :bar => /123/)
      end
      
      route_to("/abc/123").should   have_route(:foo => "abc",  :bar => "123")
      route_to("/abcd/123").should  have_route(:foo => "abcd", :bar => "123")
      route_to("/abc/1234").should  have_route(:foo => "abc",  :bar => "1234")
      route_to("/abcd/1234").should have_route(:foo => "abcd", :bar => "1234")
      route_to("/ab/123").should    have_nil_route
      route_to("/abc/12").should    have_nil_route
      route_to("/ab/12").should     have_nil_route
    end
    
    it "should allow creating conditions that span default segment dividers" do
      Merb::Router.prepare do |r|
        r.match!("/:controller", :controller => %r[^[a-z]+/[a-z]+$])
      end
      
      route_to("/somewhere").should have_nil_route
      route_to("/somewhere/somehow").should have_route(:controller => "somewhere/somehow")
    end
    
    it "should allow creating conditions that match everything" do
      Merb::Router.prepare do |r|
        r.match!("/:glob", :glob => /.*/)
      end
      
      %w(somewhere somewhere/somehow 123/456/789 i;just/dont-understand).each do |path|
        route_to("/#{path}").should have_route(:glob => path)
      end
    end
    
    it "should allow greedy matches to preceed segments" do
      Merb::Router.prepare do |r|
        r.match!("/foo/:bar/something/:else", :bar => /.*/)
      end
      
      %w(somewhere somewhere/somehow 123/456/789 i;just/dont-understand).each do |path|
        route_to("/foo/#{path}/something/wonderful").should have_route(:bar => path, :else => "wonderful")
      end
    end
    
    it "should allow creating conditions that proceed a glob" do
      Merb::Router.prepare do |r|
        r.match!("/:foo/bar/:glob", :glob => /.*/)
      end
      
      %w(somewhere somewhere/somehow 123/456/789 i;just/dont-understand).each do |path|
        route_to("/superblog/bar/#{path}").should have_route(:foo => "superblog", :glob => path)
        route_to("/notablog/foo/#{path}").should have_nil_route
      end
    end
    
    it "should match only if all mixed conditions are satisied" do
      Merb::Router.prepare do |r|
        r.match!("/:blog/post/:id", :blog => %r{^[a-zA-Z]+$}, :id => %r{^[0-9]+$})
      end
      
      route_to("/superblog/post/123").should      have_route(:blog => "superblog",  :id => "123")
      route_to("/superblawg/post/321").should     have_route(:blog => "superblawg", :id => "321")
      route_to("/superblog/post/asdf").should     have_nil_route
      route_to("/superblog1/post/123").should     have_nil_route
      route_to("/ab/12").should                   have_nil_route
    end
  end
  
  describe "a route containing host variable conditions" do
    
    it "should be awesome" do
      pending "Nothing is implemented here yet"
    end
    
  end
  
  describe "a route built with nested conditions" do
    
    it "should support block matchers as a path namespace" do
      Merb::Router.prepare do |r|
        r.match("/foo") { |path| path.match("/bar").to(:controller => "one/two", :action => "baz") }
      end
      
      route_to("/foo/bar").should have_route(:controller => "one/two", :action => "baz")
    end
    
    it "should be able to nest named segment variables" do
      Merb::Router.prepare do |r|
        r.match("/:first") do |first|
          first.match!("/:second")
        end
      end
      
      route_to("/one/two").should have_route(:first => "one", :second => "two")
      route_to("/one").should     have_nil_route
    end
    
    it "should be able to define a route and still use the context for more route definition" do
      Merb::Router.prepare do |r|
        r.match("/hello") do |h|
          h.to(:controller => "foo", :action => "bar")
          h.match("/world").to(:controller => "hello", :action => "world")
        end
      end
      
      route_to("/hello").should have_route(:controller => "foo", :action => "bar")
      route_to("/hello/world").should have_route(:controller => "hello", :action => "world")
    end
    
    it "should be able to add blank paths without effecting the actual path" do
      Merb::Router.prepare do |r|
        r.match("/foo") do |p|
          p.match("").to(:controller => "one/two", :action => "index")
        end
      end
      
      route_to("/foo").should have_route(:controller => "one/two", :action => "index")
    end
    
    it "should be able to merge path and request method conditions" do
      Merb::Router.prepare do |r|
        r.match("/:controller") do |f|
          f.match(:protocol => "https://").to(:action => "bar")
        end
      end
      
      route_to("/foo").should have_nil_route
      route_to("/foo", :protocol => "https://").should have_route(:controller => "foo", :action => "bar")
    end
    
    it "should be able to override previously set Request method conditions" do
      Merb::Router.prepare do |r|
        r.match(:domain => "foo.com") do |foo|
          foo.match("/", :domain => "bar.com").to(:controller => "bar", :action => "com")
        end
      end
      
      route_to("/").should                       have_nil_route
      route_to("/", :domain => "foo.com").should have_nil_route
      route_to("/", :domain => "bar.com").should have_route(:controller => "bar", :action => "com")
    end
    
    it "should be able to override previously set named segment variable conditions" do
      Merb::Router.prepare do |r|
        r.match("/:account", :account => /^\d+$/) do |account|
          account.match!(:account => /^[a-z]+$/)
        end
      end
      
      route_to("/abc").should have_route(:account => "abc")
      route_to("/123").should have_nil_route
    end
    
    it "should be able to set conditions on named segment variables that haven't been used yet" do
      Merb::Router.prepare do |r|
        r.match(:account => /^[a-z]+$/) do |account|
          account.match!("/:account")
        end
      end
      
      route_to("/abc").should have_route(:account => "abc")
      route_to("/123").should have_nil_route
    end
    
    it "should be able to merge path and request method conditions when both kinds are specified in the parent match statement" do
      Merb::Router.prepare do |r|
        r.match("/:controller", :protocol => "https://") do |f|
          f.match("/greets").to(:action => "bar")
        end
      end
      
      route_to("/foo").should have_nil_route
      route_to("/foo/greets").should have_nil_route
      route_to("/foo", :protocol => "https://").should have_nil_route
      route_to("/foo/greets", :protocol => "https://").should have_route(:controller => "foo", :action => "bar")
    end
    
    it "allows wrapping of nested routes all having shared argument with PREDEFINED VALUES" do
      pending "I'm not sure which file this spec should live."
      Merb::Router.prepare do |r|
        r.match(/\/?(en|es|fr|be|nl)?/).to(:language => "[1]") do |l|
          l.match("/guides/:action/:id").to(:controller => "tour_guides")
        end
      end

      route_to('/nl/guides/search/denboss').should have_route(:controller => 'tour_guides', :action => "search", :id => "denboss", :language => "nl")
      route_to('/es/guides/search/barcelona').should have_route(:controller => 'tour_guides', :action => "search", :id => "barcelona", :language => "es")
      route_to('/fr/guides/search/lille').should have_route(:controller => 'tour_guides', :action => "search", :id => "lille", :language => "fr")
      route_to('/en/guides/search/london').should have_route(:controller => 'tour_guides', :action => "search", :id => "london", :language => "en")
      route_to('/be/guides/search/brussels').should have_route(:controller => 'tour_guides', :action => "search", :id => "brussels", :language => "be")

      route_to('/guides/search/brussels').should have_route(:controller => 'tour_guides', :action => "search", :id => "brussels")
      pending "I don't think that this should pass (it does on the current router)" do
        route_to('/se/guides/search/stokholm').should have_route(:controller => 'tour_guides', :action => "search", :id => "stokholm", :language => nil)
      end
    end
    
  end

  describe "multiple routes" do
    it "should not leak conditions" do
      Merb::Router.prepare do |r|
        r.match("/root") do |r|
          r.match('/foo').to
          r.match('/bar').to(:hello => "world")
        end
      end
      
      route_to("/root/bar").should have_route(:hello => "world")
    end
  end
end