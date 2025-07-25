import React, { useEffect, useState } from "react";
import { ChakraProvider, Box, Heading, Text, Image, VStack, Spinner, Button, Modal, ModalOverlay, ModalContent, ModalHeader, ModalFooter, ModalBody, ModalCloseButton, useDisclosure, Input, FormLabel, useToast } from "@chakra-ui/react";
import axios from "axios";
import AddItemModal from "./AddItemModal";
import QueryImage from "./QueryImage";
import RemoveItem from "./RemoveItem";

const API_URL = process.env.REACT_APP_API_URL || "http://127.0.0.1:8000";

function ItemList() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedItem, setSelectedItem] = useState(null);
  const [viewImagesItem, setViewImagesItem] = useState(null);
  const [viewImages, setViewImages] = useState([]);
  const [viewImagesLoading, setViewImagesLoading] = useState(false);
  const { isOpen: isAddOpen, onOpen: onAddOpen, onClose: onAddClose } = useDisclosure();
  const { isOpen: isViewOpen, onOpen: onViewOpen, onClose: onViewClose } = useDisclosure();
  const [files, setFiles] = useState([]);
  const toast = useToast();

  useEffect(() => {
    async function fetchItems() {
      try {
        const res = await axios.get(`${API_URL}/items/`);
        setItems(res.data.items);
      } catch (err) {
        setItems([]);
      } finally {
        setLoading(false);
      }
    }
    fetchItems();
  }, []);

  const handleOpenModal = (item) => {
    setSelectedItem(item);
    setFiles([]);
    onAddOpen();
  };

  const handleUpload = async () => {
    if (!selectedItem || files.length === 0) {
      toast({ title: "Please select images.", status: "warning" });
      return;
    }
    try {
      for (let file of files) {
        const formData = new FormData();
        formData.append("item_id", selectedItem.item_id);
        formData.append("file", file);
        await axios.post(`${API_URL}/upload/`, formData, { headers: { "Content-Type": "multipart/form-data" } });
      }
      toast({ title: "Images added!", status: "success" });
      setFiles([]);
      onAddClose();
    } catch (err) {
      toast({ title: "Upload failed.", status: "error" });
    }
  };

  const handleViewImages = async (item) => {
    setViewImagesItem(item);
    setViewImagesLoading(true);
    try {
      const res = await axios.get(`${API_URL}/item_images/${item.item_id}`);
      setViewImages(res.data.images);
    } catch {
      setViewImages([]);
    } finally {
      setViewImagesLoading(false);
      onViewOpen();
    }
  };

  const handleDeleteImage = async (img) => {
    if (!viewImagesItem) return;
    try {
      await axios.delete(`${API_URL}/item_image/${viewImagesItem.item_id}/${img}`);
      setViewImages(viewImages.filter(i => i !== img));
      toast({ title: "Image deleted!", status: "success" });
    } catch {
      toast({ title: "Delete failed.", status: "error" });
    }
  };

  return (
    <Box borderWidth={1} borderRadius="md" p={4} mb={4}>
      <Heading size="md" mb={2}>Existing Items</Heading>
      {loading ? <Spinner /> : (
        <VStack align="start" spacing={4}>
          {items.map(item => (
            <Box key={item.item_id} display="flex" alignItems="center">
              <Image src={item.preview_image} boxSize="60px" objectFit="cover" mr={3} borderRadius="md" />
              <Box>
                <Text fontWeight="bold">{item.item_name}</Text>
                <Text fontSize="sm" color="gray.500">ID: {item.item_id}</Text>
                <Button size="sm" mt={1} onClick={() => handleOpenModal(item)} colorScheme="blue" mr={2}>Add Images</Button>
                <Button size="sm" mt={1} onClick={() => handleViewImages(item)} colorScheme="teal">View Images</Button>
              </Box>
            </Box>
          ))}
          {items.length === 0 && <Text>No items found.</Text>}
        </VStack>
      )}
      <Modal isOpen={isAddOpen} onClose={onAddClose} size="md">
        <ModalOverlay />
        <ModalContent>
          <ModalHeader>Add Images to {selectedItem?.item_name}</ModalHeader>
          <ModalCloseButton />
          <ModalBody>
            <FormLabel>Images</FormLabel>
            <Input type="file" accept="image/*" multiple onChange={e => setFiles(Array.from(e.target.files))} />
            <Text fontSize="sm" color="gray.500">You can select multiple images.</Text>
          </ModalBody>
          <ModalFooter>
            <Button colorScheme="blue" mr={3} onClick={handleUpload}>Upload</Button>
            <Button variant="ghost" onClick={onAddClose}>Cancel</Button>
          </ModalFooter>
        </ModalContent>
      </Modal>
      <Modal isOpen={isViewOpen && !!viewImagesItem} onClose={onViewClose} size="lg">
        <ModalOverlay />
        <ModalContent>
          <ModalHeader>Images for {viewImagesItem?.item_name}</ModalHeader>
          <ModalCloseButton />
          <ModalBody>
            {viewImagesLoading ? <Spinner /> : (
              <VStack align="start" spacing={2}>
                {viewImages.map((img, idx) => (
                  <Box key={idx} display="flex" alignItems="center">
                    <Image src={img} boxSize="120px" objectFit="cover" borderRadius="md" mr={2} />
                    <Button size="sm" colorScheme="red" onClick={() => handleDeleteImage(img)}>Delete</Button>
                  </Box>
                ))}
                {viewImages.length === 0 && <Text>No images found.</Text>}
              </VStack>
            )}
          </ModalBody>
        </ModalContent>
      </Modal>
    </Box>
  );
}

function App() {
  const [items, setItems] = useState([]);
  useEffect(() => {
    async function fetchItems() {
      try {
        const res = await axios.get(`${API_URL}/items/`);
        setItems(res.data.items);
      } catch (err) {
        setItems([]);
      }
    }
    fetchItems();
  }, []);

  return (
    <ChakraProvider>
      <Box maxW="md" mx="auto" mt={10} p={6} borderWidth={1} borderRadius="lg" boxShadow="md">
        <Heading mb={4}>Warehouse Image Recognition</Heading>
        <Text mb={2}>Upload images, remove items, and query the database.</Text>
        <ItemList />
        <AddItemModal />
        <RemoveItem />
        <QueryImage />
      </Box>
    </ChakraProvider>
  );
}

export default App;
