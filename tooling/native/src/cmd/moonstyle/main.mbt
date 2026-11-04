///|
async fn main {
  @signal.set_global_cancellation_signals([@signal.SIGINT, @signal.SIGTERM])
  let status = @async.handle_cancellation(async fn() {
    @cli.run(@env.args()[1:].to_owned())
  })
  @sys.exit(status.unwrap_or(0))
}
