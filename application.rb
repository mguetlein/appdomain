require 'rubygems'
require 'opentox-ruby'

require 'app_domain.rb'

before do
  app_domain_params = {}
  params.each do |k,v|
    if k.to_s=~/^app_domain_param_/
      app_domain_params[k.to_s.gsub(/^app_domain_param_/,"")] = v
      params.delete(k)
    end
  end
  if app_domain_params.size>0
    value = ""
    app_domain_params.each do |k,v|
      value += ";" if value.size>0
      value += k.to_s+"="+v.to_s
    end
    params[:app_domain_params] = value
  end  
end  

post '/:app_domain_alg/:id' do
  model = AppDomain::AppDomainModel.get(params[:id])
  raise OpenTox::NotFoundError.new("app-domain-model '#{params[:id]}' not found.") unless model
  LOGGER.info "applying appdomain model #{model.uri} with params #{params.inspect}"
  [:dataset_uri].each do |p|
    raise OpenTox::BadRequestError.new("#{p} missing") unless params[p].to_s.size>0
  end

  dataset = model.find_predicted_dataset(params[:dataset_uri])
  if dataset
    LOGGER.info "found already existing appdomain result: #{dataset}"
    dataset
  else
    task = OpenTox::Task.create( "Apply Model #{model.uri}", url_for("/", :full) ) do |task|
      res = model.apply(params[:dataset_uri], task)
      LOGGER.info "appdomain prediction result: #{res}"
      res  
    end
    return_task(task)
  end
end

post '/:app_domain_alg' do
  [:dataset_uri, :prediction_feature].each do |p|
    raise OpenTox::BadRequestError.new("#{p} missing") unless params[p].to_s.size>0
  end
  LOGGER.info "building app-domain model with params #{params.inspect}"
  
  model = AppDomain::AppDomainModel.find_model(params)
  if model
    LOGGER.info "found already existing appdomain model: #{model}"
    model
  else
    task = OpenTox::Task.create( "Create Model", url_for("/", :full) ) do |task|
      model = AppDomain::AppDomainModel.create(params,@subjectid)
      model.build(task)
      LOGGER.info "appdomain model created: #{model.uri}"
      model.uri
      end
    return_task(task)
  end  
end

get '/?' do
  LOGGER.debug "list appdomain models #{params.inspect}"
  uri_list = AppDomain::AppDomainModel.all.sort.collect{|v| v.uri}.join("\n") + "\n"
  if request.env['HTTP_ACCEPT'] =~ /text\/html/
    content_type "text/html"
    OpenTox.text_to_html uri_list,@subjectid
  else
    content_type "text/uri-list"
    uri_list
  end
end

get '/:app_domain_alg/:id' do
  LOGGER.debug "get appdomain model #{params.inspect}"
  model = AppDomain::AppDomainModel.get(params[:id])
  raise OpenTox::NotFoundError.new("app-domain-model '#{params[:id]}' not found.") unless model
  case request.env['HTTP_ACCEPT']
  when "application/rdf+xml"
    content_type "application/rdf+xml"
    model.to_rdf
  when /text\/html/
    model.inspect
    OpenTox.text_to_html model.to_yaml
  else
    raise "not yet implemented"
  end  
end

delete '/:app_domain_alg/:id' do
  model = AppDomain::AppDomainModel.get(params[:id])
  raise OpenTox::NotFoundError.new("app-domain-model '#{params[:id]}' not found.") unless model
  LOGGER.info "delete appdomain model #{model.uri} #{params.inspect}"
  model.delete
  content_type "text/plain"
  "deleted model with id #{params[:id]}\n"
end

get '/:app_domain_alg/:id/predicted/:prop' do
  model = Weka::WekaModel.get(params[:id])
    raise OpenTox::NotFoundError.new("app-domain-model '#{params[:id]}' not found.") unless model
  model.subjectid = @subjectid
  if params[:prop] == "value"
    feature = model.prediction_value_feature
  else
    raise OpenTox::BadRequestError.new "Unknown URI #{@uri}"
  end
  case @accept
  when /yaml/
    content_type "application/x-yaml"
    feature.metadata.to_yaml
  when /rdf/
    content_type "application/rdf+xml"
    feature.to_rdfxml
  when /html/
    content_type "text/html"
    OpenTox.text_to_html feature.metadata.to_yaml
  else
    raise OpenTox::BadRequestError.new "Unsupported MIME type '#{@accept}'"
  end
end



