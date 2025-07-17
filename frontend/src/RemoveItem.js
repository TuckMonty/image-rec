import React, { useState } from "react";
import { Box, Button, Input, FormLabel, useToast } from "@chakra-ui/react";
import axios from "axios";

const API_URL = process.env.REACT_APP_API_URL || "http://127.0.0.1:8000";

export default function RemoveItem() {
  const [itemId, setItemId] = useState("");
  const toast = useToast();

  const handleRemove = async () => {
    if (!itemId) {
      toast({ title: "Please provide an item ID.", status: "warning" });
      return;
    }
    try {
      await axios.delete(`${API_URL}/item/${itemId}`);
      toast({ title: "Item removed!", status: "success" });
    } catch (err) {
      toast({ title: "Remove failed.", status: "error" });
    }
  };

  return (
    <Box borderWidth={1} borderRadius="md" p={4} mb={4}>
      <FormLabel>Item ID to Remove</FormLabel>
      <Input value={itemId} onChange={e => setItemId(e.target.value)} placeholder="Enter item ID" mb={2} />
      <Button colorScheme="red" onClick={handleRemove}>Remove Item</Button>
    </Box>
  );
}
