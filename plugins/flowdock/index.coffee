NotificationPlugin = require "../../notification-plugin"
Handlebars = require 'handlebars'

class Flowdock extends NotificationPlugin
  BASE_URL = "https://api.flowdock.com/v1"

  @receiveEvent: (config, event, callback) ->
    return if event?.trigger?.type == "linkExistingIssue"


    subject = "#{event.trigger.message} in #{event.project.name}"
    if event.error && event.error && event.error.releaseStage
      subject += " (#{event.error.releaseStage})"

    link = if event.error
             event.error.url
           else
             event.project.url

    if event.trigger.type == 'projectSpiking'
      subject = 'Spike detected'
      link = event.project.url
      event.spiking = true

    # Flowdock projects can only contain alphanumeric characters, "_" and " "
    project = event.project.name.replace(/[^\w_]+/g, ' ')

    payload =
      source: "Bugsnag"
      from_address: "notifications@bugsnag.com"
      from_name: "Bugsnag"
      format: "html"
      subject: subject
      project: project
      content: @render event
      link: link

    @request
      .post("#{BASE_URL}/messages/team_inbox/#{config.apiToken}")
      .timeout(4000)
      .send(payload)
      .set("User-Agent", "Bugsnag")
      .on "error", (err) ->
        callback err
      .end (res) ->
        callback(res.error)

  @render: Handlebars.compile '
    {{#if comment}}
      <p>{{user.name}}</b> commented on <b>{{error.exceptionClass}} {{error.message}}</b> (<a href="{{error.url}}">details</a>)</p>
      <p>"{{comment.message}}"</p>
    {{else}}
      {{#if spiking}}
        <p>Spike of <strong>{{trigger.rate}}</strong> exceptions/minute in
        <a href="{{project.url}}">{{project.name}}</a></p>
        <p>Most recent error: {{error.exceptionClass}} {{error.message}}
        (<a href="{{error.url}}">details</a>)</p>
      {{else}}
        {{#if error}}
          <p>
            <a href="{{error.url}}">
              <strong>{{error.exceptionClass}} in {{error.context}}</strong>
            </a>
            <br/>
            {{error.message}}
          </p>
          {{#if error.releaseStage}}
            <p>Release stage: {{error.releaseStage}}</p>
          {{/if}}
          {{#if error.appVersion}}
            <p>App version: {{error.appVersion}}</p>
          {{/if}}

          <p><strong>Stacktrace summary</strong></p>
          <table>
          {{#eachSummaryFrame error.stacktrace}}
            <tr><td><tt>{{file}}:{{lineNumber}} - {{method}}</tt></td></tr>
          {{/eachSummaryFrame}}
          </table>
        {{else}}
          {{trigger.message}} in <a href="{{project.url}}">{{project.name}}</a>
        {{/if}}
      {{/if}}
    {{/if}}
    '

module.exports = Flowdock
