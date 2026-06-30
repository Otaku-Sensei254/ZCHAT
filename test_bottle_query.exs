# Test script to debug bottle query
alias Vibeflow.Chat.BottleService
alias Vibeflow.Chat.{Message, ConversationMember}
alias Vibeflow.Repo
import Ecto.Query

receiver_id = 6

# Check if receiver is a member of any conversations with bottle messages
IO.puts("\n=== Checking conversation memberships for user #{receiver_id} ===")

memberships =
  from(cm in ConversationMember,
    where: cm.user_id == ^receiver_id,
    select: cm.conversation_id
  )
  |> Repo.all()

IO.inspect(memberships, label: "User #{receiver_id} is member of conversations")

# Check bottle messages in those conversations
IO.puts("\n=== Bottle messages in those conversations ===")

if length(memberships) > 0 do
  bottles =
    from(m in Message,
      where: m.is_bottle == true and m.conversation_id in ^memberships,
      select: [:id, :content, :is_found, :bottle_origin_id, :conversation_id]
    )
    |> Repo.all()

  IO.inspect(bottles, label: "Bottles in user's conversations")
else
  IO.puts("User is not a member of any conversations!")
end

# Test the actual wash_up_bottle_to_randomo function
IO.puts("\n=== Testing wash_up_bottle_to_randomo ===")
result = BottleService.wash_up_bottle_to_randomo(receiver_id)
IO.inspect(result, label: "wash_up_bottle_to_randomo(#{receiver_id}) result")

# Check if bottles are now found
IO.puts("\n=== Checking if any bottles are now found ===")
found_bottles =
  from(m in Message,
    where: m.is_bottle == true and m.is_found == true,
    select: [:id, :content, :conversation_id, :bottle_origin_id]
  )
  |> Repo.all()

IO.inspect(found_bottles, label: "Found bottles (is_found=true)")
