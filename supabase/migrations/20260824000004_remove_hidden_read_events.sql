-- FR-37: Read receipts OFF emits no read event and stores no hidden record.

delete from public.message_reads
where receipt_visible = false;

alter table public.message_reads
  drop constraint if exists message_reads_receipt_visible_check;

alter table public.message_reads
  add constraint message_reads_receipt_visible_check
  check (receipt_visible = true);
