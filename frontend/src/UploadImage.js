import React, { useState } from "react";
import { Box, Button, Input, FormLabel, VStack, useToast } from "@chakra-ui/react";
import axios from "axios";

const API_URL = process.env.REACT_APP_API_URL || "http://127.0.0.1:8000";

export default function UploadImage() {
  const [itemId, setItemId] = useState("");
  const [file, setFile] = useState(null);
  const toast = useToast();

  const handleUpload = async () => {
    if (!itemId || !file) {
      toast({ title: "Please provide an item ID and select a file.", status: "warning" });
      return;
    }
    const formData = new FormData();
    formData.append("item_id", itemId);
    formData.append("file", file);
    try {
      await axios.post(`${API_URL}/upload/`, formData, { headers: { "Content-Type": "multipart/form-data" } });
      toast({ title: "Image uploaded!", status: "success" });
    } catch (err) {
      toast({ title: "Upload failed.", status: "error" });
    }
  };

  return (
    <Box borderWidth={1} borderRadius="md" p={4} mb={4}>
      <FormLabel>Item ID</FormLabel>
      <Input value={itemId} onChange={e => setItemId(e.target.value)} placeholder="Enter item ID" mb={2} />
      <FormLabel>Image File</FormLabel>
      <Input type="file" accept="image/*" onChange={e => setFile(e.target.files[0])} mb={2} />
      <Button colorScheme="blue" onClick={handleUpload}>Upload Image</Button>
    </Box>
  );
}
