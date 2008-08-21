require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe "When recognizing requests," do
  
  describe "a route a simple param builder" do
    
    it "should provide the params specified in 'to' statements" do
      Merb::Router.prepare do |r|
        r.match('/hello').to(:foo => "bar")
      end

      route_to("/hello").should have_route(:foo => "bar")
    end

    it "should only contain an :action key if no params are defined" do
      # This because all routes have :action => "index" as a default
      Merb::Router.prepare do |r|
        r.match('/hello').to_route.register
      end

      route_to('/hello').should have_exact_route(:action => "index")
    end

    it "should be able to extract named segments as params" do
      Merb::Router.prepare do |r|
        r.match!('/:foo')
      end

      route_to('/bar').should have_route(:foo => "bar")
    end

    it "should be able to extract multiple named segments as params" do
      Merb::Router.prepare do |r|
        r.match!("/:foo/:faz")
      end

      route_to("/bar/baz").should have_route(:foo => "bar", :faz => "baz")
    end

    it "should not extract a named segment if it did not match the condition assigned to it" do
      Merb::Router.prepare do |r|
        r.match!("/:foo", :foo => /^[a-z]$/)
      end

      route_to("/123").should_not have_route(:foo => "123")
    end
  end
  
  describe "a route a complex param builder" do
    
    it "should be able to prepend to the named segment" do
      Merb::Router.prepare do |r|
        r.match('/:foo').to(:foo => 'bar/:foo')
      end
      
      route_to("/hello").should have_route(:foo => 'bar/hello')
    end
    
    it "should be able to append to the named segment" do
      Merb::Router.prepare do |r|
        r.match('/:foo').to(:foo => ':foo/bar')
      end
      
      route_to("/hello").should have_route(:foo => "hello/bar")
    end
    
    it "should be able to not alter the named segment" do
      Merb::Router.prepare do |r|
        r.match('/:foo').to(:foo => ':foo')
      end
      
      route_to("/hello").should have_route(:foo => "hello")
    end
    
    it "should be able to insert the named segment into phrases" do
      Merb::Router.prepare do |r|
        r.match("/:greetings").to(:greetings => "I say :greetings to you good sir!")
      end
      
      route_to("/good-day").should have_route(:greetings => "I say good-day to you good sir!")
    end
    
    it "should be able to extract a specified capture from a regular expression path condition" do
      Merb::Router.prepare do |r|
        r.match(%r[/([a-z]+)/world]).to(:greetings => "[1]")
      end
      
      route_to("/hello/world").should have_route(:greetings => "hello")
    end
    
    it "should be able to extract a specified capture from a regular expression named segment" do
      Merb::Router.prepare do |r|
        r.match("/:foo", :foo => %r[\d+([a-z]*)\d+]).to(:foo => ":foo[1]")
      end
      
      pending "This doesn't work" do
        route_to("/123abc1").should have_route(:foo => "abc")
      end
    end
    
    it "should be able to extract a specified capture from a regular expression condition on an arbitrary request method" do
      Merb::Router.prepare do |r|
        r.match(:domain => %r[([a-z]+)\.world\.com]).to(:greetings => ":domain[1]")
      end
      
      route_to("/blah", :domain => "hello.world.com").should have_route(:greetings => "hello")
    end
    
    it "should be able to combine multiple regular expression extractions into a single param" do
      Merb::Router.prepare do |r|
        r.match(%r[/([a-z]+)/world], :domain => %r[([a-z]+)\.world\.com]).to(:combined => ":domain[1] :path[1]")
      end
      
      route_to("/goodbye/world", :domain => "hello.world.com").should have_route(:combined => "hello goodbye")
    end
  end
  
  describe "a route with nested to blocks" do
    
    it "should merge all the params together" do
      Merb::Router.prepare do |r|
        r.to(:controller => "foo") do |f|
          f.match("/hello").to(:action => "bar")
        end
      end
      
      route_to("/hello").should have_route(:controller => "foo", :action => "bar")
    end
    
    it "should overwrite previous params with newer params" do
      Merb::Router.prepare do |r|
        r.to(:controller => "foo") do |f|
          f.match("/hello").to(:controller => "bar")
        end
      end
      
      route_to("/hello").should have_route(:controller => "bar")
    end
  
    it "should preserve existing conditions" do
      Merb::Router.prepare do |r|
        r.match("/foo").to(:controller => "foo") do |a|
          a.to(:action => "bar")
        end
      end
      
      route_to("/foo").should have_route(:controller => "foo", :action => "bar")
    end
    
    it "should be preserved through condition blocks" do
      Merb::Router.prepare do |r|
        r.to(:controller => "foo") do |f|
          f.match!('/blah')
        end
      end
      
      route_to("/blah").should have_route(:controller => "foo")
    end
    
    it "should preserve existing defaults" do
      Merb::Router.prepare do |r|
        r.defaults(:action => "bar").to(:controller => "foo") do |a|
          a.match!("/(:action)")
        end
      end
      
      route_to("/").should have_route(:controller => "foo", :action => "bar")
    end
    
    it "should be preserved through defaults blocks" do
      Merb::Router.prepare do |r|
        r.to(:controller => "foo") do |f|
          f.defaults(:action => "bar").match!("/blah")
        end
      end
      
      route_to("/blah").should have_route(:controller => "foo")
    end
  end
end