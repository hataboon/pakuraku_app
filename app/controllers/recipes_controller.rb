class RecipesController < ApplicationController
  require 'httpclient'
  def index
    if params[:search].blank?
      query = "banana"
    else
      query = params[:search]
    end
    client = HTTPClient.new()
    res = client.get("https://api.edamam.com/api/recipes/v2?type=public&q=#{query}&app_id=#{ENV['application_id']}&app_key=#{ENV['application_keys']}")
    @foods = JSON.parse(res.body)
  end
end
