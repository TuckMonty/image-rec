import React, { useState } from "react";
import {
  Box,
  Button,
  Input,
  FormLabel,
  useToast,
  Modal,
  ModalOverlay,
  ModalContent,
  ModalHeader,
  ModalFooter,
  ModalBody,
  ModalCloseButton,
  useDisclosure,
  VStack,
  Text
} from "@chakra-ui/react";
import axios from "axios";

const API_URL = process.env.REACT_APP_API_URL || "http://127.0.0.1:8000";

function generateRandomId() {
  return Math.random().toString(36).substring(2, 10);
}

export default function AddItemModal() {
  const { isOpen, onOpen, onClose } = useDisclosure();
  const [itemName, setItemName] = useState("");
  const [itemId, setItemId] = useState(generateRandomId());
  const [files, setFiles] = useState([]);
  const toast = useToast();

  const handleOpen = () => {
    setItemId(generateRandomId());
    setItemName("");
    setFiles([]);
    onOpen();
  };

  const handleUpload = async () => {
    if (!itemName || files.length === 0) {
      toast({ title: "Please provide an item name and select images.", status: "warning" });
      return;
    }
    try {
      for (let file of files) {
        const formData = new FormData();
        formData.append("item_id", itemId);
        formData.append("item_name", itemName);
        formData.append("file", file);
        await axios.post(`${API_URL}/upload/`, formData, { headers: { "Content-Type": "multipart/form-data" } });
      }
      toast({ title: `Item '${itemName}' added!`, status: "success" });
      onClose();
    } catch (err) {
      toast({ title: "Upload failed.", status: "error" });
    }
  };

  return (
    <Box mb={4}>
      <Button colorScheme="blue" onClick={handleOpen}>Add New Item</Button>
      <Modal isOpen={isOpen} onClose={onClose} size="md">
        <ModalOverlay />
        <ModalContent>
          <ModalHeader>Add New Item</ModalHeader>
          <ModalCloseButton />
          <ModalBody>
            <VStack align="stretch" spacing={3}>
              <FormLabel>Item Name</FormLabel>
              <Input value={itemName} onChange={e => setItemName(e.target.value)} placeholder="Enter item name" />
              <FormLabel>Item ID (auto-generated)</FormLabel>
              <Input value={itemId} isReadOnly mb={2} />
              <FormLabel>Images</FormLabel>
              <Input type="file" accept="image/*" multiple onChange={e => setFiles(Array.from(e.target.files))} />
              <Text fontSize="sm" color="gray.500">You can select multiple images.</Text>
            </VStack>
          </ModalBody>
          <ModalFooter>
            <Button colorScheme="blue" mr={3} onClick={handleUpload}>Upload</Button>
            <Button variant="ghost" onClick={onClose}>Cancel</Button>
          </ModalFooter>
        </ModalContent>
      </Modal>
    </Box>
  );
}
