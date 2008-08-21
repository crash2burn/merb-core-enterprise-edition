require File.join(File.dirname(__FILE__), '..', "spec_helper")

describe "When recognizing requests," do

  describe "a route with a Regexp path condition" do
    
    it "should allow mixing regular expression paths with string paths when nesting match blocks"
    
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
    Merb::Router.prepare do |r|
      r.match(%r[^/foo/(.+)], :user_agent => /(MSIE|Gecko)/).
        to(:controller => "foo", :title => "[1]", :action => "show", :agent => ":user_agent[1]")
    end
    route_to("/foo/bar", :user_agent => /MSIE/).should have_route(
      :controller => "foo", :action => "show", :title => "bar", :agent => "MSIE"
    )
  end

  it "should allow wrapping of nested routes all having shared OPTIONAL argument" do
    Merb::Router.prepare do |r|
      r.match(/\/?(.*)?/).to(:language => "[1]") do |l|
        l.match("/guides/:action/:id").to(:controller => "tour_guides")
      end
    end

    route_to('/guides/search/london').should have_route(:controller => 'tour_guides', :action => "search", :id => "london")
  end

end