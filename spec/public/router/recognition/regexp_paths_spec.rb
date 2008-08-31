require File.join(File.dirname(__FILE__), '..', "spec_helper")

describe "When recognizing requests," do

  describe "a route with a Regexp path condition" do
    
    it "should allow a regex expression" do
      Merb::Router.prepare do
        match(%r{^/foos?/(bar|baz)/([a-z0-9]+)}).to(:controller => "foo", :action => "[1]", :id => "[2]")
      end
      
      route_to("/foo/bar/baz").should  have_route(:controller => "foo", :action => "bar", :id => "baz")
      route_to("/foos/bar/baz").should have_route(:controller => "foo", :action => "bar", :id => "baz")
      route_to("/bars/foo/baz").should have_nil_route
    end
    
    it "should allow mixing regular expression paths with string paths" do
      Merb::Router.prepare do
        match(%r{^/(foo|bar)/baz/([a-z0-9]+)}).to(:controller => "[1]", :action => "baz", :id => "[2]")
      end
      
      route_to("/foo/baz/bar").should have_route(:controller => "foo", :action => "baz", :id => "bar")
      route_to("/bar/baz/foo").should have_route(:controller => "bar", :action => "baz", :id => "foo")
      route_to("/for/bar/baz").should have_nil_route
    end
    
    it "should allow mixing regular expression paths with string paths when nesting match blocks" do
      Merb::Router.prepare do
        match("/buh/") do
          match(%r{^(foo|bar)/baz/([a-z0-9]+)}).to(:controller => "[1]", :action => "baz", :id => "[2]")
        end
      end
      
      route_to("/buh/foo/baz/1").should   have_route(:controller => "foo", :action => "baz", :id => "1")
      route_to("/buh/bar/baz/buh").should have_route(:controller => "bar", :action => "baz", :id => "buh")
      route_to("/buh/baz/foo/buh").should have_nil_route
    end
  end

end

describe "Old Regexp path specs" do

  before(:each) do
    pending "These are old specs"
  end
  
  it "should process a simple regex" do
    prepare_route(%r[^/foos?/(bar|baz)/([a-z0-9]+)], :controller => "foo", :action => "[1]", :id => "[2]")
    route_to("/foo/bar/baz").should have_route(:controller => "foo", :action => "bar", :id => "baz")
    route_to("/foos/baz/bam").should have_route(:controller => "foo", :action => "baz", :id => "bam")
  end

  it "should support inbound user agents" do
    Merb::Router.prepare do
      match(%r[^/foo/(.+)], :user_agent => /(MSIE|Gecko)/).
        to(:controller => "foo", :title => "[1]", :action => "show", :agent => ":user_agent[1]")
    end
    route_to("/foo/bar", :user_agent => /MSIE/).should have_route(
      :controller => "foo", :action => "show", :title => "bar", :agent => "MSIE"
    )
  end

  it "should allow wrapping of nested routes all having shared OPTIONAL argument" do
    Merb::Router.prepare do
      match(/\/?(.*)?/).to(:language => "[1]") do
        match("/guides/:action/:id").to(:controller => "tour_guides")
      end
    end

    route_to('/guides/search/london').should have_route(:controller => 'tour_guides', :action => "search", :id => "london")
  end

end